# Testing document

Test plan, test cases with results, and the list of bugs found and fixed for
OmniLife. The same tables are in `docs/TESTING.xlsx`.

## How to run

```bash
flutter pub get
flutter test
```

Run one file with `flutter test test/core/sync/sync_engine_test.dart`.

## Result summary

Automated run of `flutter test` on 2026-10-21 (Windows):

| Measure | Value |
|---|---|
| Automated tests run | 862 |
| Passed | 862 |
| Failed | 0 |
| Stability | Four consecutive full runs passed (see BUG-15 for the random failures that were fixed) |

Manual test cases cover what an automated test cannot prove: a notification
on a real phone, GPS, pedometer, microphone, the real Firebase console.

Test cases listed below: 72. Pass: 60. Manual (to be demonstrated, not yet passed): 11. Fail: 1.

Status meaning: Pass means an automated test proves it and the test file is
named in the Actual result. "Manual - to be demonstrated" means it has not
been run yet and will be shown live. Fail means it was run and did not pass.

## Authentication

| Test ID | Module | Description | Input / steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|---|
| AUTH-01 | Authentication | Register with valid details | Name, valid email, password of 8+ chars, same confirmation | Account created, user lands on dashboard | Automated: successful register clears error and reaches authenticated (test/presentation/controllers/auth_controller_test.dart) | Pass |
| AUTH-02 | Authentication | Register with invalid email | Email `abc@` and valid password | Validation message under the email field, no request sent | Automated: rejects malformed email (test/core/utils/validators_test.dart); shows validation errors on empty submit (test/presentation/pages/register_page_test.dart) | Pass |
| AUTH-03 | Authentication | Register with short password | Password `abc12` | Message that password needs at least 8 characters | Automated: rejects passwords shorter than 8 characters (test/core/utils/validators_test.dart) | Pass |
| AUTH-04 | Authentication | Register with mismatched confirmation | Password and confirmation differ | Message that passwords do not match | Automated: rejects mismatched passwords (test/presentation/pages/register_page_test.dart, test/core/utils/validators_test.dart) | Pass |
| AUTH-05 | Authentication | Login with correct credentials | Registered email and password | User signed in, dashboard shown | Automated: reflects authenticated status when repository emits a user (test/presentation/controllers/auth_controller_test.dart) | Pass |
| AUTH-06 | Authentication | Login with wrong password | Registered email, wrong password | Friendly error shown, loading cleared, stays on login | Automated: login failure surfaces the message and clears loading (test/presentation/controllers/auth_controller_test.dart); friendly texts in test/core/errors/auth_error_messages_test.dart | Pass |
| AUTH-07 | Authentication | Login with unknown user | Email never registered | Friendly 'no account' style message | Automated: test/core/errors/auth_error_messages_test.dart | Pass |
| AUTH-08 | Authentication | Forgot password | Registered email, tap Forgot password | Reset email sent and confirmation shown | Reset mail delivery needs the real Firebase project | Manual - to be demonstrated |
| AUTH-09 | Authentication | Google sign-in | Tap Continue with Google | Signed in; cancelling shows no error | Automated: successful signInWithGoogle..., handles cancellation... (test/presentation/controllers/auth_controller_test.dart); button in test/presentation/pages/login_page_test.dart. Real Google account flow on a device is manual | Pass |
| AUTH-10 | Authentication | Session persists after restart | Sign in, close app fully, reopen | Splash then dashboard without login | Needs a device or browser restart with real Firebase | Manual - to be demonstrated |
| AUTH-11 | Authentication | Logout | Tap logout | Returns to login, per-user data cleared from view | Automated: logout drives status back to unauthenticated (auth_controller_test.dart); clears tasks on sign out (task_controller_test.dart) | Pass |
| AUTH-12 | Authentication | Protected route redirects when signed out | Open /tasks while signed out | Redirect to login; after login the page opens | Automated: signed out is sent to login from a protected route; deep link while signed out lands on login (test/app/routes/auth_guard_test.dart) | Pass |

## Core features

| Test ID | Module | Description | Input / steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|---|
| CORE-01 | Tasks | Create task | Title, priority High, due date tomorrow | Task listed, saved locally and queued for sync | Automated: createTask inserts task both in repo and controller list (test/presentation/controllers/task_controller_test.dart) | Pass |
| CORE-02 | Tasks | Complete task | Tap checkbox | Task marked completed, metrics update | Automated: toggleTask toggles completion (task_controller_test.dart) | Pass |
| CORE-03 | Tasks | Delete task | Delete a task | Task removed from list and repository | Automated: deleteTask removes task from state and repository (task_controller_test.dart) | Pass |
| CORE-04 | Calendar | Create calendar event | Title, date, start and end time | Event shown in month, week and day views | Automated: createEvent adds event optimistically and persists in repo (test/presentation/controllers/calendar_controller_test.dart) | Pass |
| CORE-05 | Calendar | Edit calendar event | Change title and time | Event updated in list | Automated: updateEvent modifies event and updates list (calendar_controller_test.dart) | Pass |
| CORE-06 | Calendar | Event after 11 PM | Create event at 11:30 PM with default end | Event saved, end clamped to 23:59 | No automated test covers the 23:59 clamp (fix 595254d); demonstrate by creating an event at 11:30 PM | Manual - to be demonstrated |
| CORE-07 | Notes | Markdown note renders | Note with heading and bold text | Rendered markdown preview | Automated: test/presentation/widgets/markdown_note_view_test.dart | Pass |
| CORE-08 | Notes | Search notes | Type a word in search | Ranked results, title matches first | Automated: test/domain/usecases/notes/note_search_ranker_test.dart | Pass |
| CORE-09 | Notes | Checklist items become tasks | Note with two unchecked items, tap convert | One task per unchecked item, no duplicates on repeat | Automated: creates one task per unchecked line...; converting twice does not duplicate tasks (test/domain/usecases/notes/convert_checklist_to_tasks_test.dart) | Pass |
| CORE-10 | Habits | Habit check-in and undo | Tap today's circle twice | First tap completes and updates streak, second undoes | Automated: toggle completes today...; toggling again undoes... (test/presentation/controllers/habits_controller_test.dart) | Pass |
| CORE-11 | Habits | Streak calculation | Logs on consecutive days with a gap | Current and longest streak correct | Automated: test/domain/usecases/habits/habit_streaks_test.dart | Pass |
| CORE-12 | Habits | 365-day heatmap | Open a habit | Grid of 365 days, 7 rows, done days marked | Automated: covers exactly 365 days ending today (test/domain/usecases/habits/heatmap_grid_test.dart) | Pass |
| CORE-13 | Goals | Goal with milestones | Create goal linked to a habit | Goal saved with milestones | Automated: test/presentation/controllers/goals_controller_test.dart | Pass |
| CORE-14 | Finance | Add transaction | Amount 250, category food | Transaction listed, totals updated | Automated: test/presentation/controllers/finance_controller_test.dart; test/presentation/pages/finance_page_test.dart | Pass |
| CORE-15 | Finance | Add transaction while signed out | Add expense without login | Message 'Sign in to save this.', nothing saved | Automated: adding a transaction while signed out says to sign in (test/presentation/controllers/signed_out_writes_test.dart) | Pass |
| CORE-16 | Finance | Budget limit and over-budget warning | Set food limit 1000, spend 1200 | Over budget by 200 shown | Automated: over budget says by how much (test/domain/services/finance_math_test.dart); test/data/repositories/budget_repository_test.dart | Pass |
| CORE-17 | Finance | Chart data | Expenses in several categories and months | Category slices and six month income vs spending | Automated: sums expenses per category...; returns six months oldest first (finance_math_test.dart) | Pass |
| CORE-18 | Finance | PDF report | Tap export PDF | Real PDF built and handed to the share sheet | Automated: builds a real PDF document (test/core/services/receipt_and_report_test.dart). Viewing the file on a phone is manual | Pass |
| CORE-19 | Finance | Rule based suggestions | Open suggestions | Rule based tips shown | Automated: rule tests in test/domain/insights/finance_suggestions_test.dart; test/presentation/pages/finance_suggestions_sheet_test.dart | Pass |
| CORE-20 | Finance | Written advice cached once per month and data | Open suggestions twice with the same data | One model call, second read from cache | Automated test 'one call per month and data, cached afterwards' fails: it expects the old cache key and the code now uses the versioned key v2_finance_... The test needs updating; behaviour is as designed (BUG-14) | Fail |
| CORE-21 | Finance | Receipt upload validation | Pick a PDF or photo, then a 12 MB file | Photo or PDF accepted, others and files over 10 MB rejected | Automated: test/core/services/receipt_and_report_test.dart | Pass |
| CORE-22 | Wellness | Daily wellness log | Water 500 ml, sleep 7 h, mood 4 | Day's log saved and shown | Automated: test/presentation/controllers/wellness_sleep_source_test.dart | Pass |
| CORE-23 | Pulse | One-tap log and undo | Tap Water, then undo | Event added immediately, then removed | Automated: water and meals get helpful defaults...; undo removes the event (test/domain/usecases/pulse_service_test.dart); test/presentation/pages/pulse_page_test.dart | Pass |
| CORE-24 | Pulse | Sleep and wake duration | Tap Sleep, later tap Wake | Duration computed from the pair | Automated: Wake closes the open sleep and calculates the duration (pulse_service_test.dart); test/domain/services/pulse/sleep_analyzer_test.dart | Pass |
| CORE-25 | Pulse | Timeline, day replay, patterns | Log events over a day | Timeline ordered, replay and pattern summary produced | Automated: test/domain/services/pulse/timeline_and_replay_test.dart, pattern_detector_test.dart, momentum_calculator_test.dart | Pass |
| CORE-26 | Focus | Focus session | Start 25 min, pause, resume, finish | Timer follows the clock, session saved once at the true end | Automated: test/domain/focus/focus_timer_test.dart; test/presentation/controllers/focus_controller_test.dart | Pass |
| CORE-27 | Reminders | Create reminder | Title and time 10 min ahead | Reminder listed under upcoming and scheduled | Automated: save creates a reminder and groups it as upcoming (test/presentation/controllers/reminders_controller_test.dart) | Pass |
| CORE-28 | Reminders | Daily repeat | Reminder with repeat daily | Repeats every day at the same time | Automated: daily cases in test/domain/assistant/reminder_time_test.dart; test/domain/entities/reminder_test.dart | Pass |
| CORE-29 | Reminders | Disable and delete | Toggle off, delete, undo | Alert cancelled on disable; delete and undo restore it | Automated: toggle off reschedules (cancels)...; delete then undo brings the same reminder back (reminders_controller_test.dart) | Pass |
| CORE-30 | Assistant | Chat creates a task | 'add task buy milk tomorrow' | Task created and confirmation shown | Automated: test/presentation/assistant/assistant_tools_test.dart, assistant_controller_test.dart (fake provider, no live model) | Pass |
| CORE-31 | Assistant | Voice input and spoken reply | Tap mic and speak | Transcript sent, reply read aloud | Needs microphone and speech services on a phone, plus GROQ_API_KEY | Manual - to be demonstrated |
| CORE-32 | Assistant | Several facts in one message | 'drank water and slept 7 hours' | Water and sleep both logged | Automated: entries in one logPulse call become one call per fact (test/domain/assistant/entries_expand_test.dart); test/presentation/assistant/linked_logging_test.dart | Pass |
| CORE-33 | Assistant | Reminder 'tonight' | Say 'remind me tonight to call mom' at 3 PM | Reminder at 9 PM today | Automated: tonight is 9 PM today (test/domain/assistant/reminder_time_test.dart) | Pass |
| CORE-34 | Assistant | Reminder 'tonight' after 9 PM | Same request at 10 PM | Reminder in about 30 minutes, not tomorrow | Automated: later-today and past-time rules in test/domain/assistant/reminder_time_test.dart | Pass |
| CORE-35 | Assistant | Daily reminder by voice | 'remind me every day at 8 to take medicine' | Daily repeat reminder created | Automated: utterance decides repeat; args only when there is no utterance (reminder_time_test.dart) | Pass |
| CORE-36 | Assistant | Expense by chat | 'spent 120 on lunch' | Transaction added in the food category | Automated: test/presentation/assistant/assistant_tools_test.dart | Pass |
| CORE-37 | Maps | Saved place and geofence | Save a place, walk inside the radius | Place saved; geofence event on entry | Automated: geofence maths and service: test/core/services/geofence_test.dart, foreground_geofence_service_test.dart, test/presentation/controllers/places_controller_test.dart. Real GPS is manual | Pass |
| CORE-38 | Sensors | Step counter | Walk 50 steps with the phone | Today's steps increase | Pedometer exists only on a phone; the aggregation logic is covered by test/core/services/step_aggregator_test.dart | Manual - to be demonstrated |
| CORE-39 | Dashboard | Next up hints | Tasks and events due soon | Next up lists the nearest items | Automated: test/domain/insights/next_up_test.dart; test/presentation/widgets/next_up_section_test.dart | Pass |

## Notifications

| Test ID | Module | Description | Input / steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|---|
| NOTIF-01 | Notifications | Reminder is scheduled | Create reminder 2 minutes ahead | Local notification scheduled with the reminder time and title | Automated: scheduling through the service: reminders_controller_test.dart, test/domain/usecases/reminder_service_test.dart, test/core/services/notification_service_test.dart | Pass |
| NOTIF-02 | Notifications | Notification fires on device | Wait for the reminder time with the app closed | System notification appears at the time | Needs an Android phone | Manual - to be demonstrated |
| NOTIF-03 | Notifications | Mark done and Snooze actions | Tap Mark done or Snooze on the notification | Task completed or reminder pushed back | Automated: test/core/services/notification_actions_test.dart | Pass |
| NOTIF-04 | Notifications | Tap opens the right screen | Tap the notification | App opens the related page | Automated: test/core/services/notification_routing_test.dart | Pass |
| NOTIF-05 | Notifications | Booking-style confirmation and notification centre | Create an item that confirms | Entry in notification centre, unread count increases | Automated: showBookingConfirmation inserts notification and increments unreadCount; markAllAsRead and clearAll (test/core/services/notification_service_test.dart; test/presentation/widgets/notification_sheet_test.dart) | Pass |
| NOTIF-06 | Notifications | Web in-app banner | Create reminder in the web build | Banner inside the page when due (no system notification) | Needs a browser session | Manual - to be demonstrated |
| NOTIF-07 | Notifications | Permission denied path | Deny notification permission | App keeps working, tells the user alerts are off | Push denial counting is covered by test/core/services/push_registration_manager_test.dart; the system permission dialog is manual | Manual - to be demonstrated |
| NOTIF-08 | Notifications | Push token registration | Sign in on a phone | Token stored under users/{uid}/devices, removed on sign out | Automated: test/core/services/push_registration_manager_test.dart | Pass |

## Database and sync

| Test ID | Module | Description | Input / steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|---|
| DB-01 | Database | Create reaches Firestore | Create a task while online | Document appears under users/{uid}/tasks within seconds | Console check on the real project | Manual - to be demonstrated |
| DB-02 | Database | Read after restart | Create items, restart the app | Items loaded from SQLite | Automated: repository tests such as test/data/repositories/task_repository_impl_test.dart and note_repository_impl_test.dart | Pass |
| DB-03 | Database | Update and delete are synced | Edit then delete a task | Update then removal queued and uploaded | Automated: a delete after a set replaces it (test/core/sync/sync_engine_test.dart); test/data/repositories/sync_enqueue_test.dart | Pass |
| DB-04 | Database | Offline write is queued then synced | Airplane mode, add note, go online | Row waits in sync_outbox, uploads when online, queue drains | Automated: online write uploads once and the queue drains to synced; nothing uploads while signed out (sync_engine_test.dart) | Pass |
| DB-05 | Database | Retry with backoff | Server rejects a write | Attempts rise with capped backoff, row kept | Automated: backoff doubles per attempt and is capped (sync_engine_test.dart) | Pass |
| DB-06 | Database | Conflict resolution last-writer-wins | Same document changed on two devices | Newer updatedAt wins, conflict event emitted | Automated: a newer server copy wins and a conflict event is emitted (sync_engine_test.dart) | Pass |
| DB-07 | Database | Write replaced during upload is not lost | Edit while the previous version uploads | Newest version still uploaded | Automated: a write replaced during upload is not dropped (sync_engine_test.dart) | Pass |
| DB-08 | Database | Per-user isolation in sync | Two accounts on one device | Only the signed-in user's writes upload | Automated: only the signed-in users writes upload; others wait (sync_engine_test.dart) | Pass |
| DB-09 | Database | Rules deny another user | User B reads users/A/tasks/t1 | Permission denied | Rule files are checked for default deny (test/security/rules_files_test.dart); a live denial needs the emulator or the real project | Manual - to be demonstrated |
| DB-10 | Database | Rules cover every collection used | Compare collections in code with firestore.rules | Every collection named, default deny present, no unconditional allow | Automated: test/security/rules_files_test.dart | Pass |
| DB-11 | Database | Schema and collections | Open the Firebase console next to docs/DATABASE.md | Collections and fields match the documented schema | Compare in the console during the demo | Manual - to be demonstrated |
| DB-12 | Database | Local schema migration | Open a database created by an older version | Tables upgraded, data kept | Automated: test/data/datasources/local/app_database_migration_test.dart | Pass |
| DB-13 | Database | Another device's data merges in | Create reminder on device A, sign in on device B | Reminder appears on B and is rescheduled | Automated: test/data/repositories/reminder_repository_impl_test.dart (merge of remote reminders) | Pass |

## Bugs found and fixed

| ID | Description | Root cause | Fix | Commit / file | Status |
|---|---|---|---|---|---|
| BUG-01 | Finance page empty on web | Firestore reads timed out after 1.5 s and returned an empty list without any error | Timeout raised to 12 s in lib/data/datasources/remote/user_scoped_firestore_datasource.dart | 37b728c | Fixed |
| BUG-02 | Assistant stopped answering | Groq retired the model llama-3.3-70b-versatile | Default changed to openai/gpt-oss-20b; openai/gpt-oss-120b used for written advice | 9b3a5fa, fff0047 | Fixed |
| BUG-03 | 'Water and sleep' in one message lost the sleep | The model returns only one tool call per reply | logPulse takes an entries array that the assistant engine expands into one call per fact (lib/domain/assistant/assistant_engine.dart) | f9bcb3a | Fixed |
| BUG-04 | Creating an event after 11 PM failed | Default end time wrapped past midnight, so the end was before the start | End time clamped to 23:59 | 595254d | Fixed |
| BUG-05 | Writes while signed out silently did nothing (guest user) | Controllers wrote with no owner id | Writes refuse and show 'Sign in to save this.' (lib/core/errors/user_messages.dart) | 42ee149 | Fixed |
| BUG-06 | 'Remind me tonight' after 9 PM was set for tomorrow | Tonight was fixed at 9 PM and past times rolled to the next day | After 9 PM the reminder is set about 30 minutes ahead (lib/domain/assistant/reminder_time.dart) | 37b728c | Fixed |
| BUG-07 | GetX 'improper use' error on the Pulse page | Obx was created outside the widget that reads the observable | Obx moved inside _Body.build | 68ca9f7 | Fixed |
| BUG-08 | flutter test broke on a Windows path with a space | The native-asset build hook of newer sqlite packages mis-quoted the path | sqflite_common_ffi and path_provider_foundation pinned in pubspec.yaml | 757d46e | Fixed |
| BUG-09 | Android release build failed | permission_handler requires compileSdk 37 | compileSdk set to 37 in android/app/build.gradle.kts; desugaring enabled for notifications | 1e105ff | Fixed |
| BUG-10 | Old advice text shown after the prompt changed | Cached advice was keyed only by month and data | Cache key carries a version prefix (v2_...) | c7ee847 | Fixed |
| BUG-11 | Sync flush races and in-flight edits lost | Flushes ran concurrently and a write replaced during upload was removed afterwards | One flush at a time, replaced-in-flight writes are kept, only the signed-in user's writes upload | 3b84149, 2312c1f | Fixed |
| BUG-12 | Receipt uploaded under a wrong file name | The file name contained the literal text ${Uuid().v4()} instead of a generated id | String interpolation corrected where the receipt storage path is built (lib/presentation/controllers/finance_controller.dart, receiptStoragePath) | 42ee149 | Fixed |
| BUG-13 | Deployed Firestore rules were open test-mode rules | The project still used the default rules from creation | Per-user rules from firestore.rules deployed with `firebase deploy --only firestore:rules` on 2026-10-21. Before deploying, 4115 allow/deny cases built from every real document were checked with the Firebase rules testing API (owner allowed, other users and signed-out denied) and all passed; then the web app was loaded cold and a write synced | (deployment, no commit) | Fixed |
| BUG-14 | Unit test for cached written advice failed | Test expected the cache key finance_2026-10_... but BUG-10 added the v2_ prefix | Expected key updated in test/domain/insights/finance_suggestions_test.dart | 6f3cdb3 | Fixed |
| BUG-15 | A few tests failed at random in full runs | Controllers read device storage on start and the tests had no mock, so a MissingPluginException arrived after a test finished; the error reporter then crashed on a stack-trace assertion and hid the cause | test/flutter_test_config.dart mocks SharedPreferences and demangles stack traces | 6f3cdb3 | Fixed |
| BUG-16 | Finance accepted a transaction while signed out (guest-user id) | A recent change made the user id fall back to guest-user | Empty id restored so it says "Sign in to save this." and writes nothing; sample data refuses when signed out | (code-fix branch) | Fixed |
| BUG-17 | Sync showed Syncing for minutes after loading sample data | Queued writes were uploaded one at a time, each in its own transaction | Uploads now go in parallel chunks, one transaction per chunk, order per document kept | 4d5b5e4 | Fixed |
| BUG-18 | Microphone button covered the start of list rows; tile counts flashed 0 | Floating button over content; counts shown before first load | Mic has its own strip; counts show a dash until the first load finishes | (code-fix branch) | Fixed |
| BUG-19 | Wellness water showed 0 ml while Pulse showed 500 ml | Two separate stores | Wellness reads and writes the Pulse water events | (code-fix branch) | Fixed |
| BUG-20 | Event creation after 11 PM failed validation | Default end time wrapped to 00:00 | End clamped to 23:59 | 595254d | Fixed |

