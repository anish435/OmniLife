# OmniLife

OmniLife is a personal life organiser built with Flutter. Tasks, calendar,
notes, habits, money, wellness and a one-tap life log live in one app, and an
optional assistant can create or log things from a typed or spoken sentence.
Data is stored on the device first and synced to Firebase per signed-in user,
so the app keeps working offline.

Course project for 23CSE465 Mobile Application Development.

- Targets: Android (primary) and web. Windows desktop is used for development only.
- State management: GetX for routing, dependency injection and controllers; BLoC for the auth flow.
- Backend: Firebase (Auth, Firestore, Storage, Messaging, Analytics, Crashlytics).
- Local storage: SQLite (sqflite) on devices, in-memory/key-value storage on web.

## Features

| Module | What it does |
|---|---|
| Authentication | Email and password register/login, Google sign-in, forgot password, session restored on restart, route guard that sends signed-out users to login. |
| Tasks | Create, edit, complete and delete tasks with priority and due date; search and filters; completion metrics. |
| Calendar | Month, week and day views; events with all-day and colour tags; tasks with due dates also appear in the agenda. |
| Notes | Markdown notes with live rendering, tags, categories, pin and archive, ranked search, and checklist items that can be converted into tasks. |
| Habits and goals | Daily or weekly habits, check-in with undo, current and longest streaks, 365-day heatmap, goals with milestones linked to habits. |
| Finance | Income and expense log with categories, per-category budgets, charts (spending by category, six-month income vs spending), receipt photo upload, PDF monthly report, written suggestions. |
| Wellness | Daily water, sleep, workout and mood log. |
| Pulse | One-tap life log (sleep, wake, water, meals and more) with undo, timeline, day replay, momentum score, pattern insights, and a sleep page with duration derived from sleep/wake pairs. |
| Focus mode | Pomodoro timer (25/5 by default) that survives app restarts, ambient audio and video, sessions saved to history. |
| Map and places | Map with saved places and a foreground geofence. Needs a phone for GPS. |
| Sensors and steps | Pedometer step counter with hourly and daily totals, flip detector. Needs a phone. |
| Reminders | One-off, daily and weekly reminders as local notifications, snooze and mark-done actions, enable/disable, delete with undo. Synced between devices and re-scheduled on sign-in. |
| Assistant | Chat and voice (speech to text and text to speech) powered by Groq. Can create tasks, events, notes, reminders and expenses, log several Pulse facts from one message, toggle habits and answer questions about spending and sleep. Optional, needs `GROQ_API_KEY`. |
| Next up | Dashboard hints for what is due or scheduled next. |
| Notifications and push | In-app notification centre, local notifications on Android, FCM device registration and topics. |
| Analytics and crash reports | Firebase Analytics events and Crashlytics error reporting. |

The app has no booking feature. The confirm, save and notify flow that a
booking would have is covered by tasks, events and reminders (see
`docs/DEMO_CHECKLIST.md`).

## Architecture

```
presentation  ->  domain  <-  data
(pages, widgets,   (entities, repository   (models, SQLite and Firestore
 controllers,       interfaces, use cases,   data sources, repository
 BLoC)              services)                implementations)
        \________________ core ________________/
        (sync engine, notification and device services, config, errors, bindings)
```

- Presentation: pages and widgets, GetX controllers per module, a BLoC for authentication.
- Domain: plain Dart entities, repository interfaces, use cases and services (streak maths, finance maths, Pulse analysis, assistant engine). No Flutter or Firebase imports.
- Data: models with `toMap` (SQLite) and `toFirestoreMap` (Firestore), local and remote data sources, repository implementations.
- Core: offline-first sync engine, notification, push, location and sensor services, bindings, error messages.

Offline-first sync: every write goes to SQLite first, then a row is added to
a `sync_outbox` table. The sync engine uploads the outbox when the device is
online and the owner of the write is signed in, retries with capped
exponential backoff, coalesces repeated writes to the same document, and
resolves conflicts by last writer wins on `updatedAt`. Details are in
`docs/architecture.md` and `docs/DATABASE.md`.

## Folder structure

```
lib/
  main.dart                 app bootstrap (Firebase, notifications, sync)
  firebase_options.dart     FlutterFire config (see Setup)
  app/
    app.dart                GetMaterialApp
    routes/                 route table, route names, auth guard
    theme/                  design system
  core/
    bindings/               GetX bindings per feature
    config/                 environment values (dart-define)
    errors/                 failures and user-facing messages
    firebase/               Firebase initialisation helpers
    services/               notifications, push, reminders, location, sensors, PDF, analytics
    sync/                   sync engine, outbox, connectivity monitor
    utils/                  validators and helpers
  data/
    assistant/              Groq provider, chat history, memory store
    datasources/local/      SQLite database and per-module local sources
    datasources/remote/     Firebase Auth and Firestore data sources, paths
    focus/ insights/        focus and insight data helpers
    models/                 data models (SQLite and Firestore maps)
    repositories/           repository implementations
  domain/
    assistant/              engine, tool definitions, reminder time rules
    entities/ repositories/ usecases/ services/ focus/ insights/
  presentation/
    assistant/              assistant tools and voice service
    bloc/                   authentication BLoC
    controllers/            GetX controllers
    pages/                  one folder per module
    widgets/                shared and per-module widgets
test/                       unit, widget and security-rule tests (mirrors lib/)
docs/                       project documentation
tools/                      Android build helper scripts for Windows and WSL
web/  android/  windows/    platform folders
firestore.rules  storage.rules  firestore.indexes.json  firebase.json
```

## Setup

Requirements: Flutter (Dart SDK 3.13 or newer, see `pubspec.yaml`), a Firebase
project, and for Android builds JDK 17 and the Android SDK.

1. Get packages.

   ```bash
   flutter pub get
   ```

2. Firebase config. These files belong to the Firebase project and are not
   all committed:
   - `lib/firebase_options.dart`: generated by `flutterfire configure`. It is tracked in this repository.
   - `android/app/google-services.json`: download from the Firebase console. It is git-ignored; every developer adds their own copy.

   See `docs/firebase-setup.md`.

3. Environment file. Copy `.env.example` to `.env` (git-ignored) and fill it in.

   ```
   GROQ_API_KEY=your key from https://console.groq.com/keys
   GROQ_MODEL=            optional, default openai/gpt-oss-20b
   AI_MEMORY_URL=         optional
   ```

   The app runs without a key; only the assistant is disabled. See `docs/assistant.md`.

## Run

```bash
# Web
flutter run -d chrome --dart-define-from-file=.env

# Android device or emulator
flutter run -d <device-id> --dart-define-from-file=.env
```

## Build

```bash
# Debug APK
flutter build apk --debug --dart-define-from-file=.env

# Release APK (install directly on a phone)
flutter build apk --release --dart-define-from-file=.env

# Release app bundle (what you upload to Google Play)
flutter build appbundle --release --dart-define-from-file=.env
```

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

`docs/APK_VS_AAB.md` explains the difference and how to install with `adb`.

On this Windows machine native Gradle cannot start, so builds run inside WSL2
through `tools/android-build.cmd`. See `docs/android-build-wsl.md`.

### Signing

`android/key.properties` and any `*.keystore` or `*.jks` file are git-ignored and must never be committed. Release builds are signed from `android/key.properties` (copy `android/key.properties.example` and point `storeFile` at your keystore). Without that file the build falls back to the debug key so teammates can still build locally. Create a keystore with:

```bash
keytool -genkeypair -v -keystore omnilife-release.keystore -alias omnilife -keyalg RSA -keysize 2048 -validity 10000
```

Register the keystore's SHA-1 and SHA-256 in the Firebase console (Project settings, Android app) so Google sign-in works, then download a fresh `google-services.json`.

## Tests

```bash
flutter test
```

The suite covers validators, auth controller and route guard, repositories,
the sync engine, streak and finance maths, Pulse analysis, the assistant
engine and tools, widgets and pages, and a test that checks the security rule
files. The latest recorded result is in `docs/TESTING.md`. Test cases mapped
to the rubric areas (authentication, notifications, database) are in the same
file and in `docs/TESTING.xlsx`.

## Security rules

Everything lives under `users/{uid}/...` and only the signed-in owner can read
or write it; all other paths are denied. Receipt photos in Cloud Storage are
per user, images or PDFs under 10 MB. See `docs/security.md`. The rules files
are `firestore.rules` and `storage.rules`.

## Documentation

| File | Contents |
|---|---|
| `docs/architecture.md` | Layers and design decisions |
| `docs/DATABASE.md` | Firestore collections, SQLite tables, sync outbox |
| `docs/security.md` | Security rules explained |
| `docs/TESTING.md`, `docs/TESTING.xlsx` | Test cases, results, bugs found and fixed |
| `docs/APK_VS_AAB.md` | APK versus AAB |
| `docs/DEMO_CHECKLIST.md` | Multi-device demo and rubric mapping |
| `docs/assistant.md` | Assistant setup and tools |
| `docs/firebase-setup.md` | Firebase project setup |
| `docs/android-build-wsl.md` | Android builds on Windows through WSL2 |
| `docs/CONTRIBUTING.md` | Branch and pull request workflow |

## Team

| Member | GitHub | Modules (from commit history) |
|---|---|---|
| Likhith Ponnada | likhith1253 | Project foundation, Firebase setup and authentication, task data layer, offline sync engine, Pulse (life log, timeline, insights, sleep), Notes upgrades, Habits heatmap and goals, Focus mode, push messaging, analytics and Crashlytics, Maps and Sensors, Reminders, Assistant (chat and voice), Android build fixes. |
| Anish Kotikalapudi | anish435 | Google sign-in, authentication screens, Tasks and projects, Calendar (month, week, day), booking and reminder notifications, project plan. |
| Prudhvi Manvith | prudhvimanvith | Notes and knowledge base, Habits and goals, Finance and budgeting, Wellness and sleep tracking, calendar layout and Next up fixes. |

Some commits appear under alternate author names for the same people (for
example "Likhith Ponnada" and "Kotikalapudi Anish"). Run
`git log --format='%an|%s'` to see the full history.

## Known limitations

- Notifications on web are shown inside the app only; scheduled system notifications need an Android phone.
- Location, geofencing, step counting and the microphone need a physical phone and granted permissions.
- The assistant needs `GROQ_API_KEY`; without it the chat explains that it is not configured.
- Release builds need your own keystore (see Signing); without it they use the debug key.
- There is no booking module.
