# Demo checklist

## Before the demo

- [ ] All devices use the same Firebase project (same `google-services.json` / `firebase_options.dart`).
- [ ] Firestore rules and Storage rules are deployed (`firestore.rules`, `storage.rules`) by the project owner.
- [ ] Release APK built with `flutter build apk --release --dart-define-from-file=.env` and installed on each member's phone (`adb install -r app-release.apk`).
- [ ] Release AAB built (`flutter build appbundle --release --dart-define-from-file=.env`) and its name and size noted in `docs/APK_VS_AAB.md`.
- [ ] Notification permission granted on each phone; battery saver off.
- [ ] Each member has their own account (three different emails).
- [ ] `GROQ_API_KEY` present in the `.env` used for the build, if the assistant is shown.
- [ ] `flutter test` result recorded in `docs/TESTING.md`.

## Multi-device sync demo (about 5 minutes)

1. Phone A: log in as member 1. Phone B: log in as member 2. Show that each
   sees an empty or different dashboard (per-user isolation).
2. Phone A: create a task and a reminder two minutes ahead.
3. Show the data in the Firebase console under `users/{uid}/tasks` and
   `users/{uid}/reminders` (see `docs/DATABASE.md`).
4. Phone C (or phone A after reinstall): log in as member 1 again. The task
   and reminder appear (sync down), and the reminder is re-scheduled.
5. Put phone A in airplane mode, create a note, turn the network back on and
   show it reaching Firestore (offline queue, `sync_outbox`).
6. When the reminder time arrives, show the system notification on the phone.
7. Web: open the web build in a browser, log in, show the same data. Explain
   that on web reminders appear as an in-app banner only.
8. Try to open another user's data (the rules deny it) or show the rules
   summary in `docs/security.md`.

## Rubric to feature mapping

Only the criteria whose wording was available when this file was written are
listed. Check the remaining criteria (A1 to J1) against the rubric sheet and add a row for each.

| Criterion | What to show | Where |
|---|---|---|
| E1 Database with well-structured schema | Firestore collections and fields, SQLite tables, outbox | `docs/DATABASE.md`, Firebase console `users/{uid}/...` |
| F2 APK versus AAB; AAB name, size, build command | Explain the difference, show `app-release.aab` with size, show the command | `docs/APK_VS_AAB.md`, `build/app/outputs/bundle/release/` |
| G1 Testing document | Test ID, description, input, expected, actual, pass/fail for authentication, booking, notification, database | `docs/TESTING.md`, `docs/TESTING.xlsx` |
| G2 Test results and bug fixing | Bugs found table with fixes and commits | `docs/TESTING.md` (Bugs found and fixed) |
| H1 Repository with README, structure, clean .gitignore | README, folder tree, `.gitignore`, no secrets tracked | repository root |
| I3 Multi-device | Two or more phones, different users, sync | Multi-device demo above |
| J1 Individual reports match git history | Each member's modules against their commits | `git log --format='%an|%s'`, README team table |

## The "booking" requirement

OmniLife has no booking module. The flow a booking test needs (collect
details, confirm, persist, notify) is covered by creating an item, either by
form or by the assistant by chat or voice:

| Booking step | In OmniLife |
|---|---|
| Enter details | Add task, calendar event or reminder (form), or say it to the assistant ("remind me tonight to call mom") |
| Confirm | The form's save button, or the assistant's confirmation message with the interpreted time |
| Persist | Written to SQLite and queued to Firestore (`tasks`, `events`, `reminders`) |
| Notify | Local notification at the reminder time; in-app notification centre; on web an in-app banner |

The test cases for this flow are in `docs/TESTING.md` under Notifications and
Core features. A commit titled "feat: add booking and reminder notifications"
by anish435 introduced the original notification service
(`showBookingConfirmation` in `lib/core/services/notification_service.dart`).

## Feature walk-through order

Dashboard and Next up, Tasks, Calendar, Notes (checklist to tasks), Habits
(heatmap and streak), Finance (chart, budget, PDF), Pulse (one-tap log, day
replay, sleep), Focus, Reminders, Assistant (voice: "water and sleep" in one
sentence), Map and Sensors (phone only).

## Before the demo: devices and data

- All devices (phones and the web page) now use the same Firebase project,
  `gen-lang-client-0609884187`, so data and reminders sync between them. Install the
  same release APK on every phone (the one signed with the OmniLife release key).
- A new account starts empty. On the dashboard, use "Load sample data" (also in the
  avatar menu) so the screens and Insights have something to show. Wait until the
  status badge says "Synced" before showing the Firebase console.
- Release APK and AAB are built with `tools\android-build.cmd release aab`; the AAB
  is signed with the same key. Keep `android/omnilife-release.keystore` and
  `android/key.properties` safe; they are not in git.
