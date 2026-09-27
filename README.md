# OmniLife

**OmniLife — AI Personal Life Operating System**

A placement-level Flutter Android application that connects Tasks,
Calendar, Notes, Habits, Finance, Wellness, Analytics, and an AI Copilot
into a single, connected personal life system — built to demonstrate
the `23CSE465 Mobile Application Development` syllabus alongside
production-style software engineering practices.

This repository is currently at its **Phase 1 foundation**: a clean,
runnable Flutter Android project shell. No application features are
implemented yet.

For the full multi-phase project plan, see
[docs/project-plan.md](docs/project-plan.md). For the target system
architecture, see [docs/architecture.md](docs/architecture.md).

## Technology direction

- Flutter / Dart
- GetX and BLoC (state management, introduced per-feature in later phases)
- Firebase (Auth, Firestore, Realtime Database, Storage, FCM, Analytics,
  Crashlytics) — not yet integrated
- SQFLite (offline persistence) — not yet integrated
- MongoDB and InfluxDB (AI logs and time-series data) — not yet integrated

## Requirements

- Flutter 3.47.1 (stable channel) or compatible
- Dart SDK `^3.13.1`
- Android SDK / Android toolchain for building and running on Android

Run `flutter doctor` to verify your local environment matches these
requirements.

## Local setup

```bash
flutter pub get
```

Copy `.env.example` to `.env` if you need local environment values (no
keys are required at this stage — Firebase/AI configuration is added in
a later phase).

## Running the application

```bash
flutter run
```

To build a debug APK:

```bash
flutter build apk --debug
```
