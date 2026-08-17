#include <WiFi.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ESP32Servo.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <RTClib.h>

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

// Tank & Food Container Calibration (Centimeters)
#define WATER_TANK_HEIGHT 20.0
#define FOOD_TANK_HEIGHT  10.0
#define MIN_DISTANCE      3.0

// Safety: max time the pump is allowed to run continuously before we force it off
#define PUMP_MAX_RUNTIME_MS 90000UL

// WiFi reconnect attempts happen every 30s
#define WIFI_RETRY_INTERVAL_MS 30000UL

// Firestore document this device writes to
#define FIRESTORE_COLLECTION "aquariums"
#define FIRESTORE_DOCUMENT   "device_01"

// Normal heartbeat interval for pushing sensor data to Firestore.
#define FIREBASE_PUSH_INTERVAL_MS 60000UL

// Water level at/below this triggers an immediate out-of-band push
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

int lastFedHour = -1;

bool pumpOn = false;
unsigned long pumpStartedAt = 0;
bool pumpFault = false; 

bool rtcOk = true;
bool oledOk = true;

unsigned long lastWifiAttempt = 0;

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

void requestImmediateFirestorePush() {
  if (firebaseTaskHandle != NULL) {
    xTaskNotifyGive(firebaseTaskHandle);
  }
}

void firebaseTask(void *parameter) {
  for (;;) {
    ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(FIREBASE_PUSH_INTERVAL_MS));

    if (WiFi.status() != WL_CONNECTED || !Firebase.ready()) {
      continue; 
    }

    SensorSnapshot snap;
    if (xSemaphoreTake(snapshotMutex, pdMS_TO_TICKS(200)) == pdTRUE) {
      snap = latestSnapshot;
      xSemaphoreGive(snapshotMutex);
    } else {
      continue;
    }

    FirebaseJson content;
    String updateMask = "waterLevel,foodLevel,pumpFault,statusMessage";
    content.set("fields/waterLevel/integerValue", snap.waterLevel);
    content.set("fields/foodLevel/integerValue", snap.foodLevel);
    content.set("fields/pumpFault/booleanValue", snap.pumpFault);
    content.set("fields/statusMessage/stringValue", snap.statusMessage);

    if (snap.tempOk) {
      content.set("fields/temperature/doubleValue", snap.temperature);
      updateMask += ",temperature";
    }

    if (snap.timeValid) {
      char ts[25];
      snprintf(ts, sizeof(ts), "%04d-%02d-%02dT%02d:%02d:%02dZ",
               snap.timestamp.year(), snap.timestamp.month(), snap.timestamp.day(),
               snap.timestamp.hour(), snap.timestamp.minute(), snap.timestamp.second());
      content.set("fields/lastUpdated/timestampValue", ts);
      updateMask += ",lastUpdated";
    }

    // String Issue Fixed Here
    String documentPath = String(FIRESTORE_COLLECTION);
    documentPath += "/";
    documentPath += String(FIRESTORE_DOCUMENT);
    
    bool ok = Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "",
                                                documentPath.c_str(), content.raw(),
                                                updateMask.c_str());
    if (!ok) {
      Serial.printf("[Firestore] push failed: %s\n", fbdo.errorReason().c_str());
    }
  }
}

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

int calculatePercentage(float distanceCm, float maxHeight) {
  if (distanceCm < 0) return 0;
  if (distanceCm >= maxHeight) return 0;
  if (distanceCm <= MIN_DISTANCE) return 100;

  float level = ((maxHeight - distanceCm) / (maxHeight - MIN_DISTANCE)) * 100.0;
  return (int)level;
}

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

  display.setCursor(0, 26);
  display.print(F("Water Level: "));
  display.print(waterLevelPct);
  display.println(F("%"));

  display.setCursor(0, 38);
  display.print(F("Food Level:  "));
  display.print(foodLevelPct);
  display.println(F("%"));

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

void setPump(bool on) {
  if (on == pumpOn) return; 
  pumpOn = on;
  digitalWrite(RELAY_PIN, on ? LOW : HIGH); 
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
  pinMode(ONE_WIRE_BUS, INPUT_PULLUP);

  digitalWrite(RELAY_PIN, HIGH); 

  dispenserServo.attach(SERVO_PIN);
  dispenserServo.write(0);

  tempSensors.begin();

  if (tempSensors.getDeviceCount() == 0) {
    Serial.println(F("DS18B20 not detected on OneWire bus (GPIO4)."));
    Serial.println(F("Add a 4.7k ohm resistor between DATA and 3.3V - the"));
    Serial.println(F("internal pull-up alone is not strong enough for OneWire."));
  }

  oledOk = display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS);
  if (!oledOk) {
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

  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 25);
  display.print(WiFi.status() == WL_CONNECTED ? F("WiFi OK, starting...") : F("WiFi failed, retrying..."));
  display.display();

  Serial.println(F("[setup] Firebase.begin()..."));
  config.api_key = FIREBASE_API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback; 
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  Serial.println(F("[setup] Firebase.begin() returned"));

  snapshotMutex = xSemaphoreCreateMutex();

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

void loop() {
  maintainWiFi();

  bool haveTime = rtcOk;
  if (haveTime) {
    now = rtc.now();
  }

  tempSensors.requestTemperatures();
  float rawTemp = tempSensors.getTempCByIndex(0);
  tempSensorOk = (rawTemp != DEVICE_DISCONNECTED_C);
  if (tempSensorOk) tempC = rawTemp;

  float waterDist = readDistance(WATER_TRIG, WATER_ECHO);
  waterLevelPct = calculatePercentage(waterDist, WATER_TANK_HEIGHT);

  float foodDist = readDistance(FOOD_TRIG, FOOD_ECHO);
  foodLevelPct = calculatePercentage(foodDist, FOOD_TANK_HEIGHT);

  bool pumpFaultJustTriggered = false;
  if (pumpOn && millis() - pumpStartedAt >= PUMP_MAX_RUNTIME_MS) {
    setPump(false);
    if (!pumpFault) pumpFaultJustTriggered = true;
    pumpFault = true;
  }

  if (pumpFault) {
    if (waterLevelPct >= 90) {
      pumpFault = false; 
    }
  } else if (waterLevelPct < 20) {
    setPump(true);
  } else if (waterLevelPct >= 90) {
    setPump(false);
  }

  if (haveTime && (now.hour() == 8 || now.hour() == 20) &&
      now.minute() == 0 && lastFedHour != now.hour()) {
    if (foodLevelPct > 5) {
      triggerFeeding();
      lastFedHour = now.hour();
    }
  }

  String msg = "NORMAL";
  if (pumpFault) msg = "PUMP FAULT!";
  else if (waterLevelPct < 20) msg = "LOW WATER!";
  else if (foodLevelPct < 15) msg = "LOW FOOD!";
  else if (!rtcOk) msg = "NO RTC!";

  if (oledOk) updateDisplay(msg);

  publishSnapshot(waterLevelPct, foodLevelPct, tempC, tempSensorOk, pumpFault,
                   msg, now, haveTime);

  static bool wasCritical = false;
  bool isCritical = (waterLevelPct <= CRITICAL_WATER_LEVEL_PCT);
  if (pumpFaultJustTriggered || (isCritical && !wasCritical)) {
    requestImmediateFirestorePush();
  }
  wasCritical = isCritical;

  delay(1000);
}