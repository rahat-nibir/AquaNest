#include <WiFi.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ESP32Servo.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <RTClib.h>

// mobizt/Firebase-ESP-Client. Note: this library is marked [DEPRECATED] by
// its author in favor of his newer, truly-async "FirebaseClient" library —
// it still works fine and is what was asked for here, just flagging it in
// case you want to plan a future migration.
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"

#include "secrets.h"  // WIFI_SSID/PASSWORD, FIREBASE_API_KEY, FIREBASE_PROJECT_ID, USER_EMAIL/PASSWORD

// OLED Display Configuration
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET     -1
#define SCREEN_ADDRESS 0x3C
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Pin Definitions
#define SERVO_PIN      13
#define ONE_WIRE_BUS   4
#define WATER_TRIG     5
#define WATER_ECHO     18
#define FOOD_TRIG      19
#define FOOD_ECHO      23
#define RELAY_PIN      26

// Light relay - PLACEHOLDER PIN. Nothing in the original firmware wired a
// light relay at all, so this is a guess at a free, safe GPIO (not used by
// anything else here, not a boot-strapping pin). Confirm/change this to
// match your actual wiring before relying on it.
#define LIGHT_RELAY_PIN 27

// Tank & Food Container Calibration (Centimeters)
#define WATER_TANK_HEIGHT 20.0
#define FOOD_TANK_HEIGHT  10.0
#define MIN_DISTANCE      3.0

// Safety: max time the pump is allowed to run continuously before we force
// it off and flag an error, no matter what the sensor says. Without this,
// a stuck/false-low water reading (sensor glitch, splash, foam on the
// surface) would leave the pump running indefinitely -> overflow / flood.
// 90s is generous for topping off a 20cm tank; tune to your pump's flow rate.
#define PUMP_MAX_RUNTIME_MS 90000UL

// WiFi reconnect attempts happen every 30s if the link drops mid-run,
// instead of only ever trying once at boot.
#define WIFI_RETRY_INTERVAL_MS 30000UL

// Firestore document this device writes to: {collection}/{document}
#define FIRESTORE_COLLECTION "aquariums"
#define FIRESTORE_DOCUMENT   "device_01"

// Normal heartbeat interval for pushing sensor data to Firestore, and
// also the remote-command poll interval (light/pump/feed are checked
// right after each push - see pollRemoteCommands()). 5s here is for a
// live demo where you want the pump/feeder to react within 1-5s of an
// app toggle; dial this back to 60s+ after the competition - at 5s this
// is roughly 12x the normal Firestore reads+writes and HTTPS/TLS
// overhead on the ESP32, which matters for battery/heat and Firestore
// quota over a long-running deployment, not just for a short demo.
#define FIREBASE_PUSH_INTERVAL_MS 5000UL

// Water level at/below this triggers an immediate out-of-band push
// (in addition to a pump fault doing the same), instead of waiting for
// the next 60s heartbeat.
#define CRITICAL_WATER_LEVEL_PCT 10

Servo dispenserServo;
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature tempSensors(&oneWire);
RTC_DS3231 rtc;

float tempC = 0.0;
bool tempSensorOk = true;
int waterLevelPct = 0;
int foodLevelPct = 0;
DateTime now;

// Track the *hour* we last fed at, not the minute. See triggerFeeding logic
// below for why "minute" alone was the bug.
int lastFedHour = -1;

// ---------------------------------------------------------------------
// Remote control (Light / Pump / Manual Feed), read back from Firestore
// -----------------------------------------------------------------------
// This library has no realtime listener for Firestore (confirmed - REST
// API only, polling is the only option), so firebaseTask polls the
// aquarium doc on the same cadence as its normal push. Plain `volatile
// bool` flags (not the mutex-guarded struct used for sensor data) are
// good enough here: each one is a single word, written by exactly one
// task and read by exactly one other, so there's no multi-field
// consistency requirement the way there is for the sensor snapshot.
bool lightOn = false; // last known ACTUAL relay state (loop()/core1 owns this)
volatile bool remoteControlAvailable = false; // false until first successful read
volatile bool remoteLightRequest = false;     // last isLightOn read from Firestore
volatile bool remotePumpRequest = false;      // last isPumpOn read from Firestore
volatile bool remoteFeedRequested = false;    // set by firebaseTask, consumed+cleared by loop()

bool pumpOn = false;
unsigned long pumpStartedAt = 0;
bool pumpFault = false; // latched until water level genuinely reads high again

bool rtcOk = true;
bool oledOk = true;

unsigned long lastWifiAttempt = 0;

// ---------------------------------------------------------------------
// Firebase / Firestore
//
// Firebase.Firestore.patchDocument() is a blocking HTTPS call — this
// library doesn't offer a callback/async form for Firestore. Calling it
// straight from loop() would stall the pump-runtime check and the
// ultrasonic pulseIn() timing for however long the HTTPS round-trip takes
// (can be a second or more on a slow/congested network).
//
// So it runs on its own FreeRTOS task pinned to the ESP32's second core
// (core 0). loop() keeps doing pump/sensor/feeding work on core 1,
// completely undisturbed. The two sides only share a small struct,
// guarded by a mutex, handed over once per loop() pass.
// ---------------------------------------------------------------------

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

struct SensorSnapshot {
  float temperature;
  bool tempOk;
  int waterLevel;
  int foodLevel;
  bool pumpFault;
  char statusMessage[24];
  DateTime timestamp;
  bool timeValid;
};

SemaphoreHandle_t snapshotMutex = NULL;
SensorSnapshot latestSnapshot;
TaskHandle_t firebaseTaskHandle = NULL;

// Called once per loop() pass to hand the latest readings to the Firebase
// task. Never blocks longer than 50ms waiting for the mutex — if the
// Firebase task happens to be mid-copy, we just skip this update and try
// again next second rather than delay the safety loop for it.
void publishSnapshot(int waterLevel, int foodLevel, float temperature, bool tempOk,
                      bool fault, const String &statusMessage, DateTime timestamp,
                      bool timeValid) {
  if (snapshotMutex == NULL) return;
  if (xSemaphoreTake(snapshotMutex, pdMS_TO_TICKS(50)) == pdTRUE) {
    latestSnapshot.waterLevel = waterLevel;
    latestSnapshot.foodLevel = foodLevel;
    latestSnapshot.temperature = temperature;
    latestSnapshot.tempOk = tempOk;
    latestSnapshot.pumpFault = fault;
    strncpy(latestSnapshot.statusMessage, statusMessage.c_str(),
            sizeof(latestSnapshot.statusMessage) - 1);
    latestSnapshot.statusMessage[sizeof(latestSnapshot.statusMessage) - 1] = '\0';
    latestSnapshot.timestamp = timestamp;
    latestSnapshot.timeValid = timeValid;
    xSemaphoreGive(snapshotMutex);
  }
}

// Wakes the Firebase task immediately instead of waiting for the next
// periodic tick — used for pump faults / critically low water (req #5).
void requestImmediateFirestorePush() {
  if (firebaseTaskHandle != NULL) {
    xTaskNotifyGive(firebaseTaskHandle);
  }
}

void firebaseTask(void *parameter) {
  for (;;) {
    // Blocks here until either FIREBASE_PUSH_INTERVAL_MS elapses (normal
    // heartbeat) or requestImmediateFirestorePush() wakes it early
    // (fault / critical level) — one wait covers both cases.
    ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(FIREBASE_PUSH_INTERVAL_MS));

    if (WiFi.status() != WL_CONNECTED || !Firebase.ready()) {
      continue; // will retry at the next tick
    }

    SensorSnapshot snap;
    if (xSemaphoreTake(snapshotMutex, pdMS_TO_TICKS(200)) == pdTRUE) {
      snap = latestSnapshot;
      xSemaphoreGive(snapshotMutex);
    } else {
      continue;
    }

    FirebaseJson content;
    String updateMask = "waterLevel,foodLevel,pumpFault,status,hubOnline";
    content.set("fields/waterLevel/integerValue", snap.waterLevel);
    content.set("fields/foodLevel/integerValue", snap.foodLevel);
    content.set("fields/pumpFault/booleanValue", snap.pumpFault);
    // Field names here must match AquariumModel.fromFirestore() in the
    // Flutter app exactly - Firestore has no schema to catch a mismatch
    // for you, it'll just silently store an extra field the app never
    // reads. "status" (not "statusMessage") and "temperatureC" (not
    // "temperature") are what the app actually looks for.
    content.set("fields/status/stringValue", snap.statusMessage);
    // hubOnline: the app defaults this to false whenever it's missing,
    // so without ever writing it the dashboard would always show the
    // hub as offline even while it's actively pushing data.
    content.set("fields/hubOnline/booleanValue", true);

    if (snap.tempOk) {
      content.set("fields/temperatureC/doubleValue", snap.temperature);
      updateMask += ",temperatureC";
    }

    if (snap.timeValid) {
      // This is the device's own RTC time in RFC3339 form — NOT a true
      // Firestore serverTimestamp field-transform. patchDocument's plain
      // content JSON can only carry literal values; a real serverTimestamp
      // sentinel requires the :commit endpoint's fieldTransforms, which
      // this library doesn't wrap. Good enough as a "last seen" as long as
      // the DS3231 stays accurate — if you need a true server-side
      // timestamp, that'd mean hand-rolling the :commit REST call instead
      // of patchDocument, happy to do that if it matters for your use case.
      char ts[25];
      snprintf(ts, sizeof(ts), "%04d-%02d-%02dT%02d:%02d:%02dZ",
               snap.timestamp.year(), snap.timestamp.month(), snap.timestamp.day(),
               snap.timestamp.hour(), snap.timestamp.minute(), snap.timestamp.second());
      content.set("fields/lastUpdated/timestampValue", ts);
      updateMask += ",lastUpdated";
    }

    // Arduino's String class and the Firebase library's internal
    // MB_String both define operator+ for (String, const char*), which
    // makes "a" + "b" + "c" ambiguous to the compiler when it has to
    // pick one. Building the path with snprintf into a plain char buffer
    // sidesteps that overload-resolution clash entirely.
    char documentPath[64];
    snprintf(documentPath, sizeof(documentPath), "%s/%s", FIRESTORE_COLLECTION, FIRESTORE_DOCUMENT);
    bool ok = Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
                                                documentPath, content.raw(),
                                                updateMask.c_str());
    if (ok) {
      Serial.println(F("[Firestore] push OK"));
    } else {
      Serial.printf("[Firestore] push failed: %s\n", fbdo.errorReason().c_str());
    }

    pollRemoteCommands(documentPath);
  }
}

// Reads isLightOn, isPumpOn, and feedRequested back from the aquarium doc.
// This is a separate GET request from the push above - patchDocument
// doesn't return the full document, so there's no way to piggyback this
// on the push itself with this library.
void pollRemoteCommands(const char *documentPath) {
  // mask: only fetch these three fields, not the whole document (cheaper
  // request, and we don't need the sensor fields we just wrote ourselves).
  if (!Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath,
                                       "isLightOn,isPumpOn,feedRequested")) {
    Serial.printf("[Firestore] command poll failed: %s\n", fbdo.errorReason().c_str());
    return;
  }

  FirebaseJson resp;
  resp.setJsonData(fbdo.payload());
  FirebaseJsonData result;

  if (resp.get(result, "fields/isLightOn/booleanValue")) {
    remoteLightRequest = result.boolValue;
  }
  if (resp.get(result, "fields/isPumpOn/booleanValue")) {
    remotePumpRequest = result.boolValue;
  }
  remoteControlAvailable = true;

  if (resp.get(result, "fields/feedRequested/booleanValue") && result.boolValue) {
    // Hand the request to loop()/core1 (which owns triggerFeeding() and
    // the servo) and clear it in Firestore right away, from here, so we
    // don't keep re-triggering it every poll cycle before core1 gets to
    // act on it, and so a genuinely new button-tap later reads as fresh.
    remoteFeedRequested = true;
    FirebaseJson clearContent;
    clearContent.set("fields/feedRequested/booleanValue", false);
    if (!Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath,
                                           clearContent.raw(), "feedRequested")) {
      Serial.printf("[Firestore] clearing feedRequested failed: %s\n", fbdo.errorReason().c_str());
    }
  }
}

// ফাংশন: যেকোনো একটি আল্ট্রাসনিক থেকে দূরত্ব মাপা
float readDistance(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000);
  if (duration == 0) return -1;
  return (duration * 0.0343) / 2.0;
}

// শতকরা হিসাব করার ফাংশন
int calculatePercentage(float distanceCm, float maxHeight) {
  if (distanceCm < 0) return 0;
  if (distanceCm >= maxHeight) return 0;
  if (distanceCm <= MIN_DISTANCE) return 100;

  float level = ((maxHeight - distanceCm) / (maxHeight - MIN_DISTANCE)) * 100.0;
  return (int)level;
}

// ওয়াইফাই কানেক্ট করা (setup-এ ব্লক করেই ঠিক আছে, কারণ এই সময় আর কিছু করার নেই)
void setupWiFi() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 25);
  display.print(F("Connecting Wi-Fi..."));
  display.display();

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    attempts++;
  }
}

// Non-blocking reconnect check for use inside loop(). Original code only
// ever connected once in setup() — if the router hiccups or the ESP32
// roams out of range for a moment, it stayed OFFLINE forever after.
//
// Note: this only calls WiFi.begin() when WiFi.status() is already
// disconnected, so in practice it won't race with the Firebase task's
// in-flight HTTPS calls (those only happen while status is CONNECTED).
// A reconnect landing at the exact instant a request is mid-flight is a
// rare, self-recovering edge case — that push just fails and retries
// next cycle.
void maintainWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  unsigned long nowMs = millis();
  if (nowMs - lastWifiAttempt >= WIFI_RETRY_INTERVAL_MS) {
    lastWifiAttempt = nowMs;
    WiFi.disconnect();
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  }
}

void updateDisplay(String statusMsg) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  // WiFi Status & Temp
  display.setCursor(0, 0);
  display.print(WiFi.status() == WL_CONNECTED ? F("WiFi: ONLINE") : F("WiFi: OFFLINE"));

  display.setCursor(0, 12);
  display.print(F("Temp: "));
  if (tempSensorOk) {
    display.print(tempC, 1);
    display.write(247);
    display.print(F("C"));
  } else {
    display.print(F("SENSOR ERR"));
  }

  // Water & Food Level Statuses
  display.setCursor(0, 26);
  display.print(F("Water Level: "));
  display.print(waterLevelPct);
  display.println(F("%"));

  display.setCursor(0, 38);
  display.print(F("Food Level:  "));
  display.print(foodLevelPct);
  display.println(F("%"));

  // Status Banner
  display.setCursor(0, 52);
  display.print(F("Status: "));
  display.println(statusMsg);

  display.display();
}

void triggerFeeding() {
  dispenserServo.write(90);
  delay(1500);
  dispenserServo.write(0);
  delay(500);
}

// Turns the pump on/off through the relay, tracking runtime so we can
// enforce PUMP_MAX_RUNTIME_MS regardless of what the sensor says.
void setPump(bool on) {
  if (on == pumpOn) return; // no state change, nothing to do
  pumpOn = on;
  digitalWrite(RELAY_PIN, on ? LOW : HIGH); // active-low relay module
  if (on) {
    pumpStartedAt = millis();
  }
}

void setup() {
  Serial.begin(115200);

  pinMode(WATER_TRIG, OUTPUT);
  pinMode(WATER_ECHO, INPUT);
  pinMode(FOOD_TRIG, OUTPUT);
  pinMode(FOOD_ECHO, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(LIGHT_RELAY_PIN, OUTPUT);

  // Internal pull-up: helps a little, but on its own it's too weak
  // (~45k ohm) for reliable OneWire communication. A real 4.7k ohm
  // resistor between GPIO4 and 3.3V is still required in hardware -
  // see the getDeviceCount() check below for how this shows up if missing.
  pinMode(ONE_WIRE_BUS, INPUT_PULLUP);

  digitalWrite(RELAY_PIN, HIGH); // পাম্প শুরুতে অফ (active-low relay)
  digitalWrite(LIGHT_RELAY_PIN, HIGH); // light off (active-low relay, same assumption as pump)

  // তোমার অরিজিনাল সার্ভো সেটআপ
  dispenserServo.attach(SERVO_PIN);
  dispenserServo.write(0);

  tempSensors.begin();

  // If this reports 0, the DS18B20 isn't responding on the bus at all —
  // by far the most common cause is missing the external pull-up
  // resistor. ESP32's internal INPUT_PULLUP (set below, ~45k ohm) is too
  // weak for reliable OneWire timing; the spec wants a real 4.7k ohm
  // resistor between the DATA pin (GPIO4) and 3.3V. Without it, reads
  // fail intermittently or constantly and getTempCByIndex() returns
  // DEVICE_DISCONNECTED_C (-127.0), which is exactly the symptom this
  // check is here to catch early instead of leaving you guessing.
  if (tempSensors.getDeviceCount() == 0) {
    Serial.println(F("DS18B20 not detected on OneWire bus (GPIO4)."));
    Serial.println(F("Add a 4.7k ohm resistor between DATA and 3.3V - the"));
    Serial.println(F("internal pull-up alone is not strong enough for OneWire."));
  }

  oledOk = display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS);
  if (!oledOk) {
    // Can't show an error on the OLED if the OLED itself is the problem —
    // this is the one failure mode that has to go to Serial instead.
    Serial.println(F("OLED init failed - check wiring/I2C address"));
  }

  rtcOk = rtc.begin();
  if (!rtcOk) {
    Serial.println(F("RTC init failed - check wiring. Feeding schedule will not run."));
  } else if (rtc.lostPower()) {
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }

  setupWiFi();

  Serial.println(WiFi.status() == WL_CONNECTED
                      ? F("[setup] WiFi connected, proceeding to Firebase init")
                      : F("[setup] WiFi did NOT connect within timeout - continuing anyway"));

  // Don't leave the OLED stuck showing "Connecting Wi-Fi..." while the
  // rest of setup() (Firebase init, task creation) runs — that's exactly
  // what makes a slow-but-fine boot look like a permanent freeze.
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 25);
  display.print(WiFi.status() == WL_CONNECTED ? F("WiFi OK, starting...") : F("WiFi failed, retrying..."));
  display.display();

  // --- Firebase setup ---
  Serial.println(F("[setup] Firebase.begin()..."));
  config.api_key = FIREBASE_API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback; // from addons/TokenHelper.h
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  Serial.println(F("[setup] Firebase.begin() returned"));

  snapshotMutex = xSemaphoreCreateMutex();

  // Pinned to core 0 so it never competes with loop() (core 1) for CPU
  // time. 12KB stack: Firebase's SSL/TLS handshake and the JSON building
  // both need real headroom — if you see this task crash-reboot the
  // device, that's the first thing to bump up.
  Serial.println(F("[setup] Creating Firebase task..."));
  xTaskCreatePinnedToCore(
      firebaseTask,
      "FirebaseTask",
      12288,
      NULL,
      1,
      &firebaseTaskHandle,
      0);
  Serial.println(F("[setup] Setup complete, entering loop()"));
}

// Set once the first loop() pass has taken real sensor readings, so the
// boot-time immediate push (added below, in loop()) carries actual data
// instead of the all-zero defaults latestSnapshot starts with before
// publishSnapshot() has ever run.
bool firstLoopDone = false;

void loop() {
  maintainWiFi();

  // RTC not detected: rtc.now() would return garbage, which could make the
  // feeding-time check fire at arbitrary/wrong times. Skip anything
  // time-based until it's actually working, and say so on the display.
  bool haveTime = rtcOk;
  if (haveTime) {
    now = rtc.now();
  }

  // টেম্পারেচার মাপা। DallasTemperature returns -127.0C for a
  // disconnected/faulty sensor — showing that as a real reading is
  // misleading, so we flag it instead.
  tempSensors.requestTemperatures();
  float rawTemp = tempSensors.getTempCByIndex(0);
  tempSensorOk = (rawTemp != DEVICE_DISCONNECTED_C);
  if (tempSensorOk) tempC = rawTemp;

  // ১. ওয়াটার লেভেল মাপা
  float waterDist = readDistance(WATER_TRIG, WATER_ECHO);
  waterLevelPct = calculatePercentage(waterDist, WATER_TANK_HEIGHT);

  // ২. ফুড লেভেল মাপা
  float foodDist = readDistance(FOOD_TRIG, FOOD_ECHO);
  foodLevelPct = calculatePercentage(foodDist, FOOD_TANK_HEIGHT);

  // পাম্প কন্ট্রোল, with a hard runtime cutoff.
  // If it's been running for PUMP_MAX_RUNTIME_MS straight, force it off and
  // latch a fault — don't let it turn back on from a low reading alone.
  // The fault only clears once the level genuinely reads high (>=90%),
  // which mainly protects against a sensor that's stuck reporting "empty".
  bool pumpFaultJustTriggered = false;
  if (pumpOn && millis() - pumpStartedAt >= PUMP_MAX_RUNTIME_MS) {
    setPump(false);
    if (!pumpFault) pumpFaultJustTriggered = true;
    pumpFault = true;
  }

  // Manual (app) pump control shares this same setPump() call, so the
  // PUMP_MAX_RUNTIME_MS cutoff above applies no matter who turned it on.
  // Priority, highest first: fault (always off) > auto low-water refill
  // (always on - a manual "off" from the app can't override this, so a
  // forgotten toggle in the app can't leave the tank to run dry) > manual
  // request from the app > auto high-water cutoff.
  if (pumpFault) {
    if (waterLevelPct >= 90) {
      pumpFault = false; // level recovered on its own (or manually) - trust it again
    }
    setPump(false);
  } else if (waterLevelPct < 20) {
    setPump(true);
  } else if (remoteControlAvailable && remotePumpRequest) {
    setPump(true);
  } else if (waterLevelPct >= 90 || remoteControlAvailable) {
    // Auto high-water cutoff, OR the app explicitly asked for pump off
    // (remoteControlAvailable && !remotePumpRequest, since the request-on
    // branch above already handled the true case).
    setPump(false);
  }

  // Light has no safety interlock - it's a straightforward mirror of
  // whatever the app last requested, applied once here so the relay only
  // toggles on an actual change instead of writing digitalWrite() every
  // single loop() pass.
  if (remoteControlAvailable && lightOn != remoteLightRequest) {
    lightOn = remoteLightRequest;
    digitalWrite(LIGHT_RELAY_PIN, lightOn ? LOW : HIGH); // active-low relay
  }

  // Manual feed request from the app (feedRequested field, polled and
  // already cleared back to false in Firestore by pollRemoteCommands() -
  // see that function for why the clear happens there and not here).
  // Consumed here on core 1, same as the schedule below, so the two can
  // never call triggerFeeding() concurrently and jam the servo.
  if (remoteFeedRequested) {
    remoteFeedRequested = false;
    if (foodLevelPct > 5) {
      triggerFeeding();
      requestImmediateFirestorePush(); // let the app see it happened, don't wait for the next heartbeat
    }
  }

  // শিডিউল অনুযায়ী ফিডিং (সকাল ৮টা ও রাত ৮টা)
  //
  // Original bug: it compared against lastFedMinute, which is always 0
  // during the trigger window. After the very first feed, lastFedMinute
  // got set to 0 — and it stayed 0 forever, since that's the only value
  // it's ever set to. Every future 08:00/20:00 check then read "0 != 0"
  // -> false, so the feeder fed the fish exactly once, ever, and then
  // silently never again.
  // Fix: compare against the *hour* instead, so 8am and 8pm are tracked
  // separately and each one fires again the next time it comes around.
  if (haveTime && (now.hour() == 8 || now.hour() == 20) &&
      now.minute() == 0 && lastFedHour != now.hour()) {
    if (foodLevelPct > 5) {
      triggerFeeding();
      lastFedHour = now.hour();
    }
  }

  // স্ট্যাটাস মেসেজ সেট করা
  String msg = "NORMAL";
  if (pumpFault) msg = "PUMP FAULT!";
  else if (waterLevelPct < 20) msg = "LOW WATER!";
  else if (foodLevelPct < 15) msg = "LOW FOOD!";
  else if (!rtcOk) msg = "NO RTC!";

  if (oledOk) updateDisplay(msg);

  // Hand the latest readings to the Firebase task every pass — cheap
  // (just a mutex-guarded struct copy), so there's no harm doing it every
  // second even though it's only actually pushed every 60s or on a fault.
  publishSnapshot(waterLevelPct, foodLevelPct, tempC, tempSensorOk, pumpFault,
                   msg, now, haveTime);

  // Immediate sync on fault / critical water level (edge-triggered, so a
  // fault or a critically-low reading that persists across many loop()
  // passes only wakes the Firebase task once, not every second).
  static bool wasCritical = false;
  bool isCritical = (waterLevelPct <= CRITICAL_WATER_LEVEL_PCT);
  if (pumpFaultJustTriggered || (isCritical && !wasCritical)) {
    requestImmediateFirestorePush();
  }
  wasCritical = isCritical;

  // Push once, right after boot, instead of waiting up to
  // FIREBASE_PUSH_INTERVAL_MS for the dashboard to show the hub as
  // online. By this point publishSnapshot() above has already run once
  // this pass, so latestSnapshot holds real readings, not zeros.
  if (!firstLoopDone) {
    firstLoopDone = true;
    requestImmediateFirestorePush();
  }

  delay(1000);
}