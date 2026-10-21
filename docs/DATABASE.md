# Database schema

OmniLife keeps data in two places:

- Cloud Firestore (cloud, per user) under `users/{uid}/...`
- SQLite on the device (`omnilife.db`), which is where the app reads and writes first

Every change is written to SQLite and queued in a `sync_outbox` table; the
sync engine then uploads it to Firestore. Security rules are described in
`docs/security.md`.

## Firestore

Everything is a subcollection of the user document, so ownership is part of
the path:

```
users (collection)
 └── {uid}                         user document (Firebase Auth uid)
      ├── tasks/{taskId}
      ├── events/{eventId}
      ├── notes/{noteId}
      ├── habits/{habitId}
      ├── habit_logs/{logId}
      ├── goals/{goalId}
      ├── expenses/{txId}
      ├── settings/budgets
      ├── wellness/{id}
      ├── life_events/{eventId}
      ├── focus_sessions/{id}
      ├── reminders/{id}
      ├── locations/{id}
      ├── sensor_daily/{yyyy-MM-dd}
      ├── devices/{tokenHash}
      └── conversations/{id}/messages/{messageId}   (reserved, see note)

Cloud Storage:  receipts/{uid}/{fileName}
```

Document ids are client generated UUIDs unless stated. Times are stored in
one of two styles depending on the module: ISO-8601 strings
(`2026-10-21T09:30:00.000`) or epoch milliseconds (integers). The style is
listed per collection. Every document that has an owner field carries
`userId` (or `uid`) equal to the path uid; the rules reject anything else.

### tasks

Document id: UUID. Module: Tasks.

| Field | Type | Example |
|---|---|---|
| userId | string | `"k3J...uid"` |
| title | string | `"Submit report"` |
| description | string | `"Chapter 4 only"` |
| completed | bool | `false` |
| priority | string (low, medium, high) | `"high"` |
| dueDate | string ISO-8601 or null | `"2026-10-22T17:00:00.000"` |
| createdAt, updatedAt | string ISO-8601 | `"2026-10-21T09:00:00.000"` |

### events (calendar)

| Field | Type | Example |
|---|---|---|
| userId | string | |
| title, description | string | `"Lab viva"` |
| startAt, endAt | string ISO-8601 | `"2026-10-22T10:00:00.000"` |
| isAllDay | bool | `false` |
| colorTag | string | `"blue"` |
| type | string (event, focusBlock) | `"event"` |
| linkedTaskId | string or null | |
| createdAt, updatedAt | string ISO-8601 | |

### notes

| Field | Type | Example |
|---|---|---|
| userId | string | |
| title | string | `"Reading list"` |
| content | string (markdown) | `"- [ ] buy book"` |
| category | string | `"General"` |
| colorTag | string | `"default"` |
| isPinned, isArchived | bool | `false` |
| tags | array of string | `["study"]` |
| createdAt, updatedAt | string ISO-8601 | |

### habits

| Field | Type | Example |
|---|---|---|
| userId | string | |
| title, description | string | `"Read 20 pages"` |
| frequency | string (daily, weekly, specificDays) | `"daily"` |
| targetDaysPerWeek | int | `5` |
| specificDays | array of int | `[1,3,5]` |
| colorTag | string | |
| currentStreak, longestStreak | int | `4`, `9` |
| createdAt, updatedAt | string ISO-8601 | |

### habit_logs

Document id is derived from the habit id and the date (`_logDocId` in `habit_repository_impl.dart`), so a day is logged once. Un-checking a day deletes the document.

| Field | Type | Example |
|---|---|---|
| habitId | string | |
| date | string `yyyy-MM-dd` | `"2026-10-21"` |
| isCompleted | bool | `true` |

### goals

| Field | Type | Example |
|---|---|---|
| userId | string | |
| title | string | `"Run 5 km"` |
| targetDescription | string | |
| targetDate | string ISO-8601 or null | |
| linkedHabitId | string or null | |
| milestones | array of map | `[{"id":"m1","title":"2 km","done":true}]` |
| createdAt, updatedAt | string ISO-8601 | |

### expenses (finance transactions)

| Field | Type | Example |
|---|---|---|
| userId | string | |
| amount | number | `249.5` |
| title | string | `"Lunch"` |
| category | string (income, food, transport, utilities, entertainment, shopping, health, other) | `"food"` |
| date | string ISO-8601 | `"2026-10-21T13:10:00.000"` |
| isIncome | bool | `false` |
| receiptUrl | string or null | Storage download URL |
| createdAt, updatedAt | string ISO-8601 | |

### settings

One document, id `budgets`. Holds per-category monthly limits.

| Field | Type | Example |
|---|---|---|
| budgets | map category -> number | `{"food": 3000, "transport": 1500}` |
| updatedAt | number (epoch ms) | |

### wellness

One document per day.

| Field | Type | Example |
|---|---|---|
| date | string ISO-8601 | `"2026-10-21T00:00:00.000"` |
| waterIntakeMl | int | `1500` |
| sleepDurationHours | number | `7.5` |
| sleepQuality | int 1-5 | `4` |
| workoutDurationMinutes | int | `30` |
| workoutType | string | `"Run"` |
| moodScore | int 1-5 | `3` |

### life_events (Pulse)

Document id: UUID. Times are epoch milliseconds so range queries need no
composite index and `updatedAt` can be compared directly for conflicts.
Deletes are tombstones.

| Field | Type | Example |
|---|---|---|
| uid | string | |
| type | string | `"sleep"`, `"wake"`, `"water"` |
| timestamp | int (epoch ms) | `1760000000000` |
| metadata | map | `{"ml": 250}` |
| createdAt, updatedAt | int (epoch ms) | |
| deleted | bool | `false` |

### focus_sessions

| Field | Type | Example |
|---|---|---|
| userId | string | |
| startedAt, endedAt | int (epoch ms, UTC) | |
| plannedSeconds, focusedSeconds | int | `1500`, `1500` |
| completed | bool | `true` |

### reminders

| Field | Type | Example |
|---|---|---|
| id | string | same as document id |
| userId | string | |
| title | string | `"Take medicine"` |
| scheduledAt | int (epoch ms) | |
| repeat | string (none, daily, weekly) | `"daily"` |
| note | string or null | |
| enabled | bool | `true` |
| createdAt, updatedAt | int (epoch ms) | |

### locations (saved places)

Owner is the path, so there is no `userId` field.

| Field | Type | Example |
|---|---|---|
| id | string | |
| name | string | `"Hostel"` |
| latitude, longitude | number | `12.9716`, `77.5946` |
| radiusMeters | number | `150` |
| linkedEventId, linkedTaskId | string or null | |
| createdAt, updatedAt | int (epoch ms) | |

### sensor_daily

Document id is the day, `yyyy-MM-dd`, so retries overwrite instead of duplicating.

| Field | Type | Example |
|---|---|---|
| date | string | `"2026-10-21"` |
| steps | int | `6421` |
| hourly | map hour -> int | `{"08": 410, "09": 980}` |
| updatedAt | int (epoch ms) | |

### devices (push tokens)

Document id is a hash of the FCM token.

| Field | Type | Example |
|---|---|---|
| token | string | |
| platform | string | `"android"` |
| updatedAt | timestamp | |

### conversations

The collection name and the rules for `conversations` and
`conversations/{id}/messages` exist, but assistant chat history is currently
kept on the device only (`lib/data/assistant/chat_history_store.dart`), so
the collection is empty in practice.

### Indexes

`firestore.indexes.json` declares no composite indexes (`"indexes": []`). The
app reads whole per-user collections or single documents and filters on the
device, so only Firestore's automatic single-field indexes are used.

### Security rules summary

```
 client request                         firestore.rules
 --------------                         ---------------
 read/write users/{uid}/<collection>/.. -> request.auth != null
                                           AND request.auth.uid == {uid}
                                           AND collection is in the allow list
                                           AND (writes) map with <= 60 fields,
                                               userId/uid == caller, title is text
 life_events                            -> + type string, timestamp/updatedAt int,
                                           deleted bool
 anything else                          -> denied

 Storage: receipts/{uid}/{file}         -> owner only, image or PDF, < 10 MB
```

A signed-in user B asking for `users/A/tasks/t1` is denied because
`request.auth.uid` (B) differs from the path uid (A). The rules are checked
for coverage by `test/security/rules_files_test.dart`.

## Local SQLite (`omnilife.db`, schema version 7)

Main tables are created in `lib/data/datasources/local/app_database.dart`;
tables of later modules are created idempotently by each data source's
`ensureSchema` (`CREATE TABLE IF NOT EXISTS`). Times are epoch milliseconds
unless noted. Migration behaviour is tested in
`test/data/datasources/local/app_database_migration_test.dart`.

| Table | Columns | Notes |
|---|---|---|
| tasks | id PK, user_id, title, description, completed, priority, due_date, created_at, updated_at | |
| calendar_events | id PK, user_id, title, description, start_at, end_at, is_all_day, color_tag, type, linked_task_id, created_at, updated_at | index on (user_id, start_at) |
| notes | id PK, user_id, title, content, category, color_tag, is_pinned, is_archived, tags (JSON text), created_at, updated_at | |
| habits | id PK, user_id, title, description, frequency, target_days_per_week, specific_days (JSON text), color_tag, current_streak, longest_streak, created_at, updated_at | |
| habit_logs | id PK, habit_id FK -> habits(id) ON DELETE CASCADE, date (text), is_completed | UNIQUE(habit_id, date) |
| finance | id PK, user_id, amount REAL, title, category, date, is_income, receipt_url, created_at, updated_at | |
| wellness_logs | id PK, user_id, date (text), water_intake_ml, sleep_duration_hours REAL, sleep_quality, workout_duration_minutes, workout_type, mood_score, synced | UNIQUE(user_id, date) |
| goals | id PK, user_id, title, target_description, target_date, linked_habit_id, milestones (JSON text), created_at, updated_at | index on user_id |
| life_events | id PK, uid, type, timestamp, metadata (JSON text), created_at, updated_at, deleted | index on (uid, timestamp) |
| focus_sessions | id PK, user_id, started_at, ended_at, planned_seconds, focused_seconds, completed | index on (user_id, started_at) |
| reminders | id PK, user_id, title, scheduled_at, repeat, note, enabled, created_at, updated_at | index on (user_id, scheduled_at) |
| saved_locations | id PK, user_id, name, latitude, longitude, radius_m, linked_event_id, linked_task_id, created_at, updated_at, synced, deleted | |
| steps daily / hourly / prefs | daily: user_id, day, steps, dirty, updated_at (PK user_id, day); hourly: user_id, day, hour, steps (PK user_id, day, hour); prefs: user_id, key, value (PK user_id, key) | owned by `steps_local_store.dart` |
| sync_outbox | see below | |

On web, where SQLite is not available, the same data is kept in a key-value
store (`key_value_store_web.dart`) with an equivalent outbox
(`key_value_sync_outbox.dart`).

## Sync outbox

Table `sync_outbox` (`lib/core/sync/sqlite_sync_outbox.dart`):

| Column | Meaning |
|---|---|
| id PK | `collection/docId`, so a newer write to the same document replaces the queued one |
| uid | owner of the write; only the signed-in user's rows are uploaded |
| collection, doc_id | Firestore target `users/{uid}/{collection}/{doc_id}` |
| type | `set` or `delete` |
| data | JSON of the Firestore map |
| updated_at | local change time, used for last-writer-wins |
| created_at | when it was queued |
| attempts, next_attempt_at, last_error | retry state with capped exponential backoff |
| state | `pending` or `failed` |

Flow:

```
 UI action -> repository -> SQLite write (immediate)
                         -> sync_outbox row (set/delete)
 connectivity restored / app start / after write
   -> SyncEngine.flush: for each pending row of the signed-in user
        if the server copy has a newer updatedAt -> keep the server copy, emit a conflict event
        else set/delete users/{uid}/{collection}/{doc_id}
        success -> remove row; failure -> attempts++, backoff, keep row
```

This behaviour is covered by `test/core/sync/sync_engine_test.dart`.
