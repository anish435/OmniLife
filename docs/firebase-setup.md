# Firebase Setup (local, per-developer)

Phase 2 added the Firebase Auth/Firestore code foundation
(`lib/core/firebase`, `lib/data/datasources/remote`,
`lib/data/repositories/auth_repository_impl.dart`), but this repository
does **not** contain a real Firebase project or credentials — none are
committed, and none should ever be.

To actually connect the app to Firebase, each developer must run this
locally:

## 1. Prerequisites

- Node.js (for the Firebase CLI) and Dart/Flutter already installed.
- Install the Firebase CLI: `npm install -g firebase-tools`
- Log in: `firebase login`
- Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`

## 2. Create (or reuse) a Firebase project

In the [Firebase console](https://console.firebase.google.com/), create a
project (or use an existing one for OmniLife) with:

- Authentication → Email/Password provider enabled
- Cloud Firestore → created in production mode (rules below)

## 3. Configure the Flutter app

From the repository root:

```bash
flutterfire configure
```

This generates `lib/firebase_options.dart` and the native Android config
(`android/app/google-services.json`) for your selected project. Both
files are **gitignored** — they are per-developer/per-environment and
must never be committed.

## 4. Firestore security rules

`firestore.rules` at the repository root implements the ownership model
from `docs/architecture.md` §5 (a user may only read/write their own
`users/{uid}` subtree). Deploy it with:

```bash
firebase deploy --only firestore:rules
```

(requires `firebase init firestore` once, to link this rules file to
your Firebase project — that step creates a local `.firebaserc`/
`firebase.json`, which are also gitignored since they can encode a
project ID).

## 5. What's already handled in code

- `initializeFirebase()` (`lib/core/firebase/firebase_bootstrap.dart`) is
  called at app startup and fails safely (logs and returns `false`)
  if native configuration is missing — the app still runs.
- `AuthRepository` / `AuthRepositoryImpl` provide register/login/logout/
  auth-state-change methods, ready for a future login/register UI.
- `UserScopedFirestoreDataSource` provides generic CRUD under
  `users/{uid}/{collection}/{docId}` for the collections listed in
  `docs/architecture.md` §5, ready for future per-feature repositories.

## What you need to provide

This repository cannot build a working Firebase connection on its own.
To complete the wiring, you (the project owner) need to:

1. Confirm which Firebase project OmniLife should use (new or existing).
2. Run `flutterfire configure` locally with that project selected.
3. Enable the Email/Password sign-in provider in the Firebase console.
4. Deploy `firestore.rules` to that project.

No fake/placeholder credentials have been added to this repository —
none of the above can be fabricated safely.
