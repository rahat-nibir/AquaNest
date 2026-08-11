# AquaNest — Setup

This is the real, wired-up version: Provider state management, live Firestore
sync, real Gemini AI chat, and a genuine ESP32-CAM MJPEG stream. Nothing here
is a mock — but three integrations need YOUR credentials to actually connect.

## 1. Install dependencies

```bash
flutter pub get
```

## 2. Firebase — required

1. Create a project at https://console.firebase.google.com (free Spark plan is fine).
2. Enable **Firestore Database**, **Authentication → Email/Password**, and **Storage**.
3. Install the FlutterFire CLI and run it from the project root:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This overwrites `lib/firebase_options.dart` with your real project's keys.
   Do NOT hand-edit that file yourself — always regenerate it this way.
4. Create at least one user under Authentication so you can log in.
5. Create the Firestore document your app reads on launch:
   ```
   Collection: aquariums
   Document ID: living-room-reef   (matches kDefaultAquariumId in main.dart)
   Fields:
     name            (string)   "Living Room Reef"
     temperatureC    (number)   26.5
     status          (string)   "Stable"
     hubOnline       (bool)     true
     esp32StreamUrl  (string)   "http://<esp32-ip>:81/stream"
     lastFedAt       (timestamp, optional)
   ```
   In production your ESP32 firmware writes `temperatureC`, `status`, and
   `hubOnline` to this doc directly (e.g. via the Firebase REST API or an
   MQTT bridge) — that's what makes the Home tab "live."
6. Schedules and snapshots are subcollections under that document
   (`aquariums/living-room-reef/schedules`, `.../snapshots`) — the app
   creates schedule entries itself via the "+ Add New Time" button, you
   don't need to seed those manually.

## 3. Gemini API key — required for the Aqua AI tab

1. Get a key from https://aistudio.google.com/apikey
2. Copy `.env.example` to `.env` and paste it in:
   ```bash
   cp .env.example .env
   ```
3. `.env` is gitignored — never commit it or push it to a public repo.

## 4. ESP32-CAM stream URL — required for the Camera tab

The Camera tab connects to whatever URL is in the `esp32StreamUrl` field
in Firestore (step 2.5 above). If you're running the standard Arduino
`CameraWebServer` example on the ESP32-CAM, that's typically:

```
http://<esp32-ip-address>:81/stream
```

Find `<esp32-ip-address>` from the Serial Monitor output when the board
boots, or from your router's DHCP client list. Both your phone/emulator
and the ESP32-CAM need to be on the same Wi-Fi network for this to work.

## 5. Run it

```bash
flutter run
```

## What's real vs. what needs your input

| Feature | Status |
|---|---|
| Provider state management | ✅ Fully wired, no `setState` for business data |
| Firestore live sync (status, schedules, snapshots) | ✅ Real, needs your Firebase project (step 2) |
| Firebase Auth login/logout | ✅ Real, needs at least one user created (step 2.4) |
| Gemini AI chat, grounded in live telemetry | ✅ Real, needs your API key (step 3) |
| ESP32-CAM MJPEG live view + snapshot upload to Storage | ✅ Real, needs your device's IP (step 4) |
| Offline auto-feeding (device-side logic) | ⛔ Not in this repo — this is Flutter app code only. Auto-feeding when offline is ESP32 firmware logic (e.g. cached schedule + RTC on the microcontroller), not something the phone app can execute. |
