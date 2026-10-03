# OmniLife — Placement-Level Master Project Plan & Technical Blueprint

**Project Name:** OmniLife — AI Personal Life Operating System  
**Course Code:** 23CSE465 Mobile Application Development  
**Target Platform:** Flutter (Android, Web & Desktop Support)  
**Architecture Pattern:** Clean Architecture (Domain, Data, Presentation) + Hybrid State Management (GetX Shell + BLoC for AI Engine)  
**Persistence Strategy:** Offline-First (SQLite via `sqflite`/`sqflite_common_ffi` + Multi-Cloud Sync via Firebase Firestore, InfluxDB & MongoDB)  
**Last Updated:** October 2026  
**Repository:** `https://github.com/anish435/OmniLife`

---

## Executive Summary

OmniLife is not a collection of isolated CRUD prototypes. It is an enterprise-grade, offline-first personal life operating system engineered to demonstrate mastery of the complete `23CSE465 Mobile Application Development` syllabus and software engineering competencies required for Tier-1 placements.

OmniLife interlinks 12 core life management domains into an automated ecosystem:
1. **AI Life Copilot** (Multi-provider LLM tool-calling agent using Gemini & Groq)
2. **Tasks & Projects** (Hierarchical task management with priorities, tags, subtasks, and offline sync)
3. **Calendar & Schedule** (Multi-view Month/Week/Day timelines, time-blocking, and bi-directional task sync)
4. **Notes & Knowledge Base** (Markdown-enabled notes, categorization, pinning, checklists, and note-to-task pipeline)
5. **Habits & Goal Tracking** (Streak calculations, flexible frequency scheduling, and completion heatmaps)
6. **Personal Finance** (Income, expense tracking, category budgets, receipt attachments, and monthly analytics)
7. **Wellness & Mood** (Hydration counter, sleep monitoring, workout logs, and non-medical mood journals)
8. **Maps & Geofencing** (Event location tagging, radius geofencing, and proximity task alerts)
9. **Sensors & Hardware** (Accelerometer/pedometer focus sessions logged into time-series InfluxDB)
10. **Media & Focus Mode** (Background audio playback, ambient video timers, and session metrics)
11. **Notifications & Cloud Messaging** (FCM remote push + local scheduled notification alarms)
12. **Analytics & Performance Insights** (Custom charts, productivity scoring, and data correlation)

---

## Table of Contents

1. [Development Strategy & Implementation Philosophy](#1-development-strategy--implementation-philosophy)
2. [End-to-End System Architecture](#2-end-to-end-system-architecture)
3. [Technology Stack & Dependency Matrix](#3-technology-stack--dependency-matrix)
4. [Design System & Anti-Slop Visual Guidelines](#4-design-system--anti-slop-visual-guidelines)
5. [Database Architecture & Schemas](#5-database-architecture--schemas)
   - 5.1 Local SQLite Relational Schema (`sqflite`)
   - 5.2 Remote Cloud Firestore NoSQL Hierarchy
   - 5.3 Time-Series InfluxDB Schema
   - 5.4 MongoDB Document Store for AI Conversation Logs
6. [Offline-First Sync Engine Specification](#6-offline-first-sync-engine-specification)
7. [Comprehensive Phase Roadmap](#7-comprehensive-phase-roadmap)
   - Phase 0: Requirements, Architecture & Clean Design System *(Completed)*
   - Phase 1: Environment, Tooling & Native Android Config *(Completed)*
   - Phase 2: Multi-Cloud Foundation & Firebase Bootstrap *(Completed)*
   - Phase 3: Application Shell, Theme Engine & Route Tree *(Completed)*
   - Phase 4: Module 0 & Authentication Experience *(Completed)*
   - Phase 5: Module 1 — Tasks & Projects *(Completed — 65 Tests Passing)*
   - Phase 6: Module 2 — Calendar & Schedule *(Completed — 32 Tests Passing, 97 Total)*
   - Phase 7: Module 3 — Notes & Knowledge Base *(Next Up)*
   - Phase 8: Module 4 — Habits & Goal Tracking
   - Phase 9: Module 5 — Personal Finance & Budgeting
   - Phase 10: Module 6 — Wellness, Sleep & Mood Journal
   - Phase 11: Module 7 — AI Life Copilot & Tool Calling Engine
   - Phase 12: Module 8 — Maps, Geofencing & Location Services
   - Phase 13: Module 9 — Sensors, Pedometer & InfluxDB Telemetry
   - Phase 14: Module 10 — Media, Audio/Video & Focus Mode
   - Phase 15: Module 11 — Push Notifications, FCM & Background Alarms
   - Phase 16: Module 12 — Analytics, Data Visualizations & Aggregations
   - Phase 17: Production Hardening, Security, Isolates & Performance
   - Phase 18: Deployment, CI/CD Pipeline & Placement Viva Portfolio
8. [Cross-Module Integration Workflows](#8-cross-module-integration-workflows)
9. [23CSE465 Syllabus Coverage Matrix](#9-23cse465-syllabus-coverage-matrix)
10. [Definition of Done (DoD) & Verification Standards](#10-definition-of-done-dod--verification-standards)
11. [Placement Viva & Technical Defense Handbook](#11-placement-viva--technical-defense-handbook)

---

## 1. Development Strategy & Implementation Philosophy

OmniLife rejects the flawed "build the entire backend first, then build the UI" model. Instead, we use a **Strict Vertical-Slice Agile Engineering Cycle**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   VERTICAL SLICE DEVELOPMENT CYCLE                     │
├────────────────────────────────────────────────────────────────────────┤
│  1. Domain Entity & Value Objects (Pure Dart, zero framework leaks)     │
│       ↓                                                                │
│  2. Abstract Repository Contract (Domain layer interface)              │
│       ↓                                                                │
│  3. Data Model with (De)serialization (SQLite row + Firestore map)     │
│       ↓                                                                │
│  4. Local SQLite DataSource (Indexed tables, migration handlers)       │
│       ↓                                                                │
│  5. Remote DataSource (User-scoped Firestore with strict timeouts)     │
│       ↓                                                                │
│  6. Repository Implementation (Offline cache + optimistic local sync)  │
│       ↓                                                                │
│  7. Use Cases (Granular business logic units)                          │
│       ↓                                                                │
│  8. State Controller (GetX / BLoC with permanent / resilient binding)  │
│       ↓                                                                │
│  9. Presentation Widgets (Solid surface tokens, micro-animations)     │
│       ↓                                                                │
│  10. Unit, Model & Widget Tests (Minimum 95%+ coverage per slice)      │
│       ↓                                                                │
│  11. Static Analysis (`flutter analyze` clean, zero lints/warnings)    │
│       ↓                                                                │
│  12. Manual Device Validation & Git Atomic Commit                      │
└────────────────────────────────────────────────────────────────────────┘
```

### Golden Engineering Rules
1. **Never Break Existing Passing Tests:** Before adding or refactoring code, run `flutter test`. Ensure all 97+ tests remain green.
2. **Offline-First Guarantee:** Every user mutation (create, update, delete, complete) must write to SQLite immediately and update reactive UI state before syncing over the network.
3. **Resilient Dependency Injection:** All root services and active feature controllers must be registered with `permanent: true` or `fenix: true` inside [initial_binding.dart](file:///d:/Projects/OmniLife/lib/core/bindings/initial_binding.dart) and route `BindingsBuilder` to prevent GetX routing disposals.
4. **No Network Deadlocks:** All remote cloud calls must implement timeout guards (1500ms max) and fall back gracefully to local cache.

---

## 2. End-to-End System Architecture

```text
                                  OMNILIFE RUNTIME
                                         │
             ┌───────────────────────────┴───────────────────────────┐
             ▼                                                       ▼
  PRESENTATION: GETX APP SHELL                           PRESENTATION: BLOC AI ENGINE
  ├── AuthController (Reactive user state)               ├── AICopilotBloc (Event-driven)
  ├── TaskController (Filter/sort/metrics)               │   ├── AIEvent: SendPrompt, ExecuteTool
  ├── CalendarController (Timeline layouts)              │   └── AIState: Idle, Streaming, Confirm
  ├── NotesController (Search/pin/tagging)               └── BLoC Observers & Telemetry
  ├── FinanceController (Budget calculations)
  ├── WellnessController (Hydration/sleep logs)
  └── Theme & Navigation Controllers
             │                                                       │
             └───────────────────────────┬───────────────────────────┘
                                         ▼
                                DOMAIN LAYER (PURE DART)
             ┌───────────────────────────────────────────────────────┐
             │ Use Cases: GetAgendaForRange, CreateTask, SyncQueue   │
             │ Entities: Task, CalendarEvent, Note, Habit, Expense   │
             │ Repository Interfaces: TaskRepo, CalendarRepo, AI...  │
             └───────────────────────────┬───────────────────────────┘
                                         ▼
                               DATA / REPOSITORY LAYER
             ┌───────────────────────────────────────────────────────┐
             │ Repository Implementations (Cache + Optimistic Write) │
             │ Data Models with toMap(), fromMap(), toFirestoreMap() │
             └───────┬───────────────────┼───────────────────┬───────┘
                     │                   │                   │
                     ▼                   ▼                   ▼
             LOCAL PERSISTENCE      FIREBASE CLOUD     EXTERNAL APIS & DBs
             ┌───────────────┐   ┌────────────────┐   ┌───────────────────┐
             │ SQLite db.v2  │   │ Firebase Auth  │   │ Gemini 1.5 Flash  │
             │ tasks         │   │ Cloud Firestore│   │ Groq LLaMA-3      │
             │ events        │   │ Cloud Storage  │   │ InfluxDB (Sensors)│
             │ notes         │   │ Cloud Functions│   │ MongoDB (AI Logs) │
             │ habits        │   │ FCM Push       │   │ OpenStreetMap/OSM │
             │ expenses      │   │ Analytics      │   │ OpenWeather API   │
             │ sync_queue    │   │ Crashlytics    │   └───────────────────┘
             └───────┬───────┘   └────────┬───────┘
                     │                    │
                     └──────────┬─────────┘
                                ▼
                     OFFLINE BACKGROUND SYNC
```

---

## 3. Technology Stack & Dependency Matrix

| Category | Technology / Package | Version | Justification & Responsibility |
|---|---|---|---|
| **Core Framework** | Flutter SDK | `^3.8.0` / Dart `^3.8.0` | Cross-platform framework with native compilation |
| **App State / DI** | `get` | `^4.6.6` | Lightweight dependency injection, reactive state, routing |
| **Complex State** | `flutter_bloc` | `^9.0.0` | Strict event-driven stream state for AI conversation tokens |
| **Local SQL DB** | `sqflite` / `sqflite_common_ffi` | `^2.4.1` | Embedded SQLite engine with migration support |
| **Local Key-Value** | `shared_preferences` | `^2.5.2` | Fast persistence for user flags, theme, and tokens |
| **Cloud Auth** | `firebase_auth` / `google_sign_in` | `^5.5.1` / `^6.2.2` | Secure email/password & OAuth2 Google identity |
| **Cloud NoSQL** | `cloud_firestore` | `^5.6.5` | Document synchronization with security rules |
| **Cloud Storage** | `firebase_storage` | `^12.4.4` | Media assets, receipt images, audio files |
| **Cloud Messaging**| `firebase_messaging` | `^15.2.4` | FCM background and foreground push notifications |
| **Local Alarms** | `flutter_local_notifications` | `^18.0.1` | Exact alarm scheduling for tasks and calendar events |
| **Time-Series DB** | `influxdb_client` | `^2.0.0` | Ingestion of sensor metrics and focus telemetry |
| **AI LLM Client** | `google_generative_ai` / `dio` | `^0.4.6` / `^5.8.0+1` | Gemini Pro / Flash SDK & Groq REST client |
| **Data Viz** | `fl_chart` | `^0.70.2` | High-performance line, bar, pie, and radar graphs |
| **Mapping / GPS** | `geolocator` / `latlong2` | `^13.0.2` / `^0.9.1` | Device GPS coordinate streaming & geofence calculus |
| **Device Sensors** | `sensors_plus` / `pedometer` | `^6.1.1` / `^4.0.1` | Accelerometer, gyroscope, step counting |
| **Media Engine** | `just_audio` / `video_player` | `^0.9.43` / `^2.9.2` | Focus mode music stream and ambient video loops |
| **Test Suite** | `flutter_test` / `mocktail` | SDK / `^1.0.4` | Clean architecture unit, widget, and mock testing |

---

## 4. Design System & Anti-Slop Visual Guidelines

OmniLife follows an **anti-slop, hyper-refined editorial aesthetic** inspired by Linear, Things 3, and Notion Calendar:

### 4.1 Strict Design Rules
- **No Purple-to-Pink Gradients:** Gradient-filled buttons, cards, and headers are banned. Surfaces must be flat, confident, and tactile.
- **Glassmorphism Ban on Core Modules:** Glass and backdrop blur stay strictly on authentication screens. Calendar, Tasks, Notes, and Finance use solid surfaces with hairline 1px borders.
- **1px Hairline Borders:** 
  - Dark Mode: `#33383F` / `#262B32`
  - Light Mode: `#DADFE3` / `#E5E7EB`
- **Typography:** Inter / Outfit with tabular figures (`FontFeature.tabularFigures()`) on all numerical, financial, and time displays.
- **Haptic Feedback:** `HapticFeedback.lightImpact()` on all primary button taps, check toggles, and view switches.

### 4.2 Semantic Token Table

| Token Name | Light Value | Dark Value | Purpose |
|---|---|---|---|
| `scaffoldBackgroundColor` | `#F8F9FC` | `#0F172A` | Base app background |
| `surface` | `#FFFFFF` | `#1E293B` | Primary cards, sheets, dialogs |
| `surfaceVariant` | `#F1F5F9` | `#262B32` | Nested containers, gutters |
| `primary` | `#6366F1` | `#818CF8` | Primary CTA, focus indicators |
| `teal` | `#14B8A6` | `#2DD4BF` | Health, wellness, habits |
| `aiAccent` | `#8B5CF6` | `#A78BFA` | Copilot actions and spark elements |
| `error` | `#EF4444` | `#F87171` | Overdue deadlines, high priority, budget alerts |
| `warning` | `#F59E0B` | `#FBBF24` | Medium priority, upcoming reminders |
| `success` | `#10B981` | `#34D399` | Task completions, positive cashflow |

---

## 5. Database Architecture & Schemas

### 5.1 Local SQLite Relational Schema (`sqflite`)

OmniLife uses a unified database manager `AppDatabase` located at `lib/data/datasources/local/app_database.dart` with schema migrations.

```sql
-- Version 1: Core Task & Sync Queue
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  completed INTEGER NOT NULL DEFAULT 0,
  priority TEXT NOT NULL DEFAULT 'medium',
  due_date INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0
);

-- Version 2: Calendar & Schedule
CREATE TABLE calendar_events (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  start_at INTEGER NOT NULL,
  end_at INTEGER NOT NULL,
  is_all_day INTEGER NOT NULL DEFAULT 0,
  color_tag TEXT NOT NULL DEFAULT 'blue',
  type TEXT NOT NULL DEFAULT 'event',
  linked_task_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (linked_task_id) REFERENCES tasks (id) ON DELETE SET NULL
);

-- Version 3: Notes & Knowledge Base (Upcoming)
CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'General',
  color_tag TEXT NOT NULL DEFAULT 'default',
  is_pinned INTEGER NOT NULL DEFAULT 0,
  is_archived INTEGER NOT NULL DEFAULT 0,
  tags TEXT, -- JSON array of strings
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Version 4: Habits & Goal Tracking (Upcoming)
CREATE TABLE habits (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  frequency TEXT NOT NULL DEFAULT 'daily', -- daily, weekly, custom
  target_days TEXT NOT NULL DEFAULT '[1,2,3,4,5,6,7]',
  current_streak INTEGER NOT NULL DEFAULT 0,
  best_streak INTEGER NOT NULL DEFAULT 0,
  color_tag TEXT NOT NULL DEFAULT 'teal',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE habit_logs (
  id TEXT PRIMARY KEY,
  habit_id TEXT NOT NULL,
  completed_date INTEGER NOT NULL,
  FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
);

-- Version 5: Personal Finance (Upcoming)
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  amount REAL NOT NULL,
  type TEXT NOT NULL, -- income, expense
  category TEXT NOT NULL,
  note TEXT,
  receipt_path TEXT,
  date INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE budgets (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  category TEXT NOT NULL,
  monthly_limit REAL NOT NULL,
  month INTEGER NOT NULL,
  year INTEGER NOT NULL
);

-- Version 6: Wellness Logs (Upcoming)
CREATE TABLE wellness_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  water_glasses INTEGER NOT NULL DEFAULT 0,
  sleep_hours REAL NOT NULL DEFAULT 0.0,
  exercise_minutes INTEGER NOT NULL DEFAULT 0,
  mood TEXT NOT NULL DEFAULT 'neutral',
  log_date INTEGER NOT NULL
);
```

### 5.2 Remote Cloud Firestore NoSQL Hierarchy

Data in Cloud Firestore is strictly user-scoped to guarantee tenant isolation:

```text
users/{uid}
  ├── profile: { displayName, email, photoUrl, theme, createdAt }
  │
  ├── tasks/{taskId}
  │     └── { title, description, completed, priority, dueDate, createdAt, updatedAt }
  │
  ├── events/{eventId}
  │     └── { title, description, startAt, endAt, isAllDay, colorTag, type, linkedTaskId }
  │
  ├── notes/{noteId}
  │     └── { title, content, category, isPinned, isArchived, tags, createdAt, updatedAt }
  │
  ├── habits/{habitId}
  │     └── { title, frequency, targetDays, currentStreak, bestStreak, colorTag }
  │     └── logs/{logId}: { completedDate }
  │
  ├── transactions/{transactionId}
  │     └── { amount, type, category, note, receiptUrl, date, createdAt }
  │
  ├── wellness/{dateKey}
  │     └── { waterGlasses, sleepHours, exerciseMinutes, mood, date }
  │
  └── conversations/{convoId}
        ├── { title, createdAt, lastMessageAt }
        └── messages/{msgId}: { role, content, toolCalls, timestamp }
```

### 5.3 Time-Series InfluxDB Schema
- **Measurement:** `focus_telemetry`
- **Tags:** `user_id`, `session_type` (Pomodoro, DeepWork, MusicFocus), `device_orientation`
- **Fields:** `accelerometer_movement_magnitude` (float), `noise_level_db` (float), `heart_rate_bpm` (int), `focus_score` (float)

### 5.4 MongoDB Document Store Schema (AI Memory & Long-Term Context)
- **Collection:** `ai_interaction_traces`
- **Document Structure:**
  ```json
  {
    "_id": "ObjectId('...')",
    "userId": "string",
    "sessionId": "string",
    "query": "Plan my Wednesday around my 2pm biology lecture",
    "intent": "schedule_day",
    "executedTools": [
      { "tool": "get_agenda_for_range", "args": { "date": "2026-10-07" }, "result": "..." },
      { "tool": "create_event", "args": { "title": "Focus: Biology Prep" }, "status": "success" }
    ],
    "llmTokensUsed": 412,
    "latencyMs": 845,
    "timestamp": "ISODate('2026-10-03T...')"
  }
  ```

---

## 6. Offline-First Sync Engine Specification

```text
               CLIENT MUTATION (e.g. Create/Update Task)
                                  │
                                  ▼
                    Step 1: Write to Local SQLite
                                  │
                                  ▼
               Step 2: Update Reactive GetX Controller
                 (Instant visual feedback on screen)
                                  │
                                  ▼
                 Is Network Connected & Responsive?
                     /                         \
                   YES                          NO
                   /                             \
                  ▼                               ▼
       Step 3A: Direct Firestore Put      Step 3B: Enqueue in SQLite
         (1500ms timeout guard)             `sync_queue` table
                  │                               │
                  ▼                               ▼
               SUCCESS                    Background Sync Worker
                                          (Triggers on connectivity
                                           change or WorkManager)
                                                  │
                                                  ▼
                                          Replays operations FIFO
                                          with exponential backoff
```

### Conflict Resolution Strategy
- **Last-Write-Wins (LWW):** Compare `updatedAt` timestamps between Firestore document and SQLite row. The higher timestamp takes precedence.
- **Deletes Tombstone:** Deletions record a deletion tombstone in `sync_queue` to ensure remote document removal even if executed while offline.

---

## 7. Comprehensive Phase Roadmap

### Phase 0: Requirements, Architecture & Clean Design System *(Completed)*
- Frozen domain models, system layers, and dependency injection guidelines.
- Solid surface color tokens, hairline borders, typography, and spacing tokens.
- Output: `docs/architecture.md`.

### Phase 1: Environment, Tooling & Native Android Config *(Completed)*
- Clean Flutter 3.8 / Dart 3.8 environment initialized.
- Android application ID: `com.omnilife.app`.
- Formatter, linter rules configured in [analysis_options.yaml](file:///d:/Projects/OmniLife/analysis_options.yaml).

### Phase 2: Multi-Cloud Foundation & Firebase Bootstrap *(Completed)*
- Firebase Core initialized via [firebase_bootstrap.dart](file:///d:/Projects/OmniLife/lib/core/firebase/firebase_bootstrap.dart) before `runApp`.
- Firebase Authentication & User-Scoped Firestore Data Source implemented.

### Phase 3: Application Shell, Theme Engine & Route Tree *(Completed)*
- Centralized [AppPages](file:///d:/Projects/OmniLife/lib/app/routes/app_pages.dart) route configuration with route bindings.
- Global theme switching (Light / Dark mode) with [AppTheme](file:///d:/Projects/OmniLife/lib/app/theme/app_theme.dart).
- Fail-safe [InitialBinding](file:///d:/Projects/OmniLife/lib/core/bindings/initial_binding.dart) registered with `GetMaterialApp`.

### Phase 4: Module 0 & Authentication Experience *(Completed)*
- Clean native animated Login & Registration screens with dot-grid canvas background.
- Responsive mobile & desktop support, password reset sheet, guest bypass.
- 10 automated widget tests passing.

### Phase 5: Module 1 — Tasks & Projects *(Completed — 65 Tests Passing)*
- Full CRUD for tasks: priority tags (High, Medium, Low), due dates, completion toggle.
- Local SQLite persistence with table indices.
- Live Dashboard widgets: progress bar, metrics, quick task addition.
- 65 unit, model, and widget tests passing.

### Phase 6: Module 2 — Calendar & Schedule *(Completed — 32 Tests Passing, 97 Total)*
- Month View: 5-week grid with event chips, today indicator, day selection.
- Week View: Sticky 7-day header, 24-hour vertical timeline, now indicator.
- Day View: Hourly timeline with non-overlapping side-by-side packed event columns.
- Bi-directional integration: tasks with due dates automatically render on calendar agenda.
- 32 new tests passing (97 total passing tests across test suite).

---

### Phase 7: Module 3 — Notes & Knowledge Base *(Next Up)*
- **Objective:** Create a flexible, modern note-taking knowledge base.
- **Key Features:**
  - Rich markdown support, code block formatting, and interactive task checklists inside notes.
  - Tagging and categories (Work, Personal, Ideas, Study).
  - Pinning notes to top, archiving older notes.
  - High-speed local search across titles, contents, and tags.
  - **One-Click "Convert Checklist to Tasks":** Automatically parses markdown `- [ ] item` into OmniLife tasks linked to the note.
- **Data Layer:** `notes` SQLite table with full-text search (FTS5) + Firestore `users/{uid}/notes` sync.
- **UI:** Masonry staggered grid, clean sheet editor, solid border cards.
- **Tests:** 15+ unit and widget tests for CRUD, search, and task conversion.

---

### Phase 8: Module 4 — Habits & Goal Tracking
- **Objective:** Build momentum-building habit loops with mathematical streak validation.
- **Key Features:**
  - Daily, weekly, or specific day frequency options.
  - Current streak and all-time best streak calculations.
  - Interactive GitHub-style 365-day consistency heatmap.
  - Habit completion sound and micro-animation.
  - Linked goal milestones (e.g. "Read 12 books" linked to "Daily 20m reading").
- **Data Layer:** `habits` and `habit_logs` tables with cascade delete.

---

### Phase 9: Module 5 — Personal Finance & Budgeting
- **Objective:** Frictionless income, expense, and budget management.
- **Key Features:**
  - Multi-category expense tracking (Food, Transit, Housing, Tech, Health).
  - Monthly budget limit per category with warning progress bars (80% threshold = amber, 100% = red).
  - Receipt image capture via camera/gallery uploaded to Firebase Storage.
  - Monthly cashflow distribution charts using `fl_chart`.
  - Export monthly report as CSV/PDF.

---

### Phase 10: Module 6 — Wellness, Sleep & Mood Journal
- **Objective:** Non-medical daily wellness tracking for holistic lifestyle balance.
- **Key Features:**
  - Quick water intake stepper (250ml per tap) with daily 2.5L target ring.
  - Sleep duration and quality rating (1 to 5 stars).
  - Workout duration tracker with activity type (Running, Gym, Yoga, Cycling).
  - Mood check-in (5 expressive vector avatars) with optional reflective sentence.
  - Correlation chart: Sleep quality vs Productivity completion rate.

---

### Phase 11: Module 7 — AI Life Copilot & Tool Calling Engine
- **Objective:** Implement a true autonomous life copilot using LLM Function Calling.
- **Key Features:**
  - Provider Abstraction: Switch seamlessly between Google Gemini 1.5 Flash and Groq LLaMA-3.
  - **Executable Tools:**
    - `create_task(title, priority, dueDate)`
    - `schedule_event(title, startAt, endAt)`
    - `create_note(title, content, tags)`
    - `log_expense(amount, category, note)`
    - `get_daily_briefing()`
  - Safe Confirmation UI: Dangerous actions (deletions, financial mutations) prompt an interactive Confirmation Card before repository execution.
  - State Management: Handled via `flutter_bloc` (`AICopilotBloc`) for streaming token support and clean event architecture.
  - Long-term memory stored in MongoDB.

---

### Phase 12: Module 8 — Maps, Geofencing & Location Services
- **Objective:** Connect physical locations with schedules and tasks.
- **Key Features:**
  - Location picker for calendar events using OpenStreetMap tiles.
  - Reverse geocoding (coordinates to street address).
  - Geofenced Tasks: Trigger notification when arriving at location (e.g. "Grocery Store" pops grocery checklist).
  - Distance calculator between current GPS position and next scheduled event.

---

### Phase 13: Module 9 — Sensors, Pedometer & InfluxDB Telemetry
- **Objective:** Demonstrate advanced hardware integration.
- **Key Features:**
  - Step counter via device pedometer hardware sensor.
  - Accelerometer-based "Flip to Focus": Placing phone face down automatically initiates Focus Mode.
  - Telemetry streamed to time-series InfluxDB instance for focus stability analytics.

---

### Phase 14: Module 10 — Media, Audio/Video & Focus Mode
- **Objective:** Fulfill Unit II media requirements with a purposeful focus studio.
- **Key Features:**
  - Binaural focus beats, white noise, and rain sounds stream using `just_audio`.
  - Looping atmospheric background focus videos (fireplace, rainy cafe, forest) using `video_player`.
  - Configurable Pomodoro timer (25m focus / 5m break) with audio gongs.
  - Background audio playback using Android foreground service.

---

### Phase 15: Module 11 — Push Notifications, FCM & Background Alarms
- **Objective:** Reliable notification system spanning cloud and device.
- **Key Features:**
  - Firebase Cloud Messaging (FCM) token generation and topic subscription (`announcements`, `tips`).
  - Local exact notifications via `flutter_local_notifications` for offline alarms.
  - Actionable notification buttons: "Mark Done", "Snooze 10m" without opening app.

---

### Phase 16: Module 12 — Analytics, Data Visualizations & Aggregations
- **Objective:** Synthesize data across all modules into actionable life intelligence.
- **Key Features:**
  - OmniLife Productivity Score (0–100 algorithm factoring task completion, habit consistency, and focus minutes).
  - Weekly productivity line chart, expense breakdown donut chart, mood radar graph.
  - All heavy aggregation computations executed in background Dart isolates via `compute()`.

---

### Phase 17: Production Hardening, Security, Isolates & Performance
- **Objective:** Elevate code to enterprise standards.
- **Key Features:**
  - Strict Firestore security rules verified against unauthenticated reads/writes.
  - Android ProGuard/R8 obfuscation configuration.
  - App startup time under 1.2s on physical hardware.
  - Zero memory leaks confirmed using Flutter DevTools Memory Profiler.

---

### Phase 18: Deployment, CI/CD Pipeline & Placement Viva Portfolio
- **Objective:** Package the project for placement presentation and public distribution.
- **Key Features:**
  - GitHub Actions workflow: automated linting, test execution, and APK generation on PR.
  - Production signed APK and AAB build scripts.
  - Interactive web demo deployed on GitHub Pages / Firebase Hosting.
  - High-resolution architecture posters and presentation slide deck.

---

## 8. Cross-Module Integration Workflows

The true power of OmniLife lies in automated cross-module data pipelines:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   CROSS-MODULE INTERCONNECTION PIPELINE                │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   [ Note: Meeting Notes ] ──► One-Click Extract Action Items           │
│                                           │                            │
│                                           ▼                            │
│                                    [ Task Created ]                    │
│                                           │                            │
│                                           ▼ Due Date Assigned          │
│                                 [ Calendar Event Added ]               │
│                                           │                            │
│                                           ▼ Location Tagged            │
│                                    [ Geofence Alert ]                  │
│                                           │                            │
│                                           ▼ Event Concluded            │
│                                [ Expense Receipt Logged ]              │
│                                           │                            │
│                                           ▼ End of Week                │
│                                [ AI Weekly Review Report ]             │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 9. 23CSE465 Syllabus Coverage Matrix

| Unit | Syllabus Requirement | OmniLife Implementation Module |
|---|---|---|
| **Unit I** | Dart OOP, Types, null-safety | Clean architecture entities, usecases, repositories |
| **Unit I** | MaterialApp, Scaffold, AppBar, FAB | Core app shell, custom appbars, speed-dial FABs |
| **Unit I** | Containers, Row, Column, Stack | Layouts across all screens, timeline hour stack |
| **Unit I** | ListView, GridView, ListTile | Task lists, calendar month grid, modules grid |
| **Unit I** | GestureDetector, InkWell, Haptics | Custom cards, timeline cells, chips |
| **Unit I** | Forms, TextFields, FormField validation | Auth login/register, task sheet, event modal |
| **Unit I** | Themes (Light & Dark Mode) | `AppTheme` light/dark tokens, semantic colors |
| **Unit I** | Navigation & Routes | Centralized `AppPages` table, GetX typed routing |
| **Unit II** | Advanced Widgets (Chips, Sliders, Pickers) | Priority choice chips, date/time pickers, water steppers |
| **Unit II** | Media Player (Audio & Video) | Focus Mode ambient audio (`just_audio`) & video (`video_player`) |
| **Unit II** | Async Dart (`Future`, `Stream`, `async/await`) | SQLite database calls, auth streams, reactive observers |
| **Unit II** | REST API & JSON Serialization | Groq/Gemini HTTP endpoints, model `toMap`/`fromMap` |
| **Unit II** | State Management (GetX & BLoC) | GetX for app-wide shell; BLoC for AI Copilot event streams |
| **Unit II** | Data Visualization & Charts | `fl_chart` line, bar, donut charts in Analytics & Dashboard |
| **Unit II** | Notifications & Push Messaging | FCM background service + local scheduled alarms |
| **Unit II** | Micro-Animations & Page Transitions | Hero transitions, animated checkmarks, card entrance fades |
| **Unit III** | Relational Database (SQLite) | `sqflite` v2 schema with foreign keys and migrations |
| **Unit III** | Cloud NoSQL Database (Firebase Firestore) | User-scoped document collections with security rules |
| **Unit III** | Specialized Databases (MongoDB & InfluxDB) | MongoDB for AI interaction traces; InfluxDB for sensor telemetry |
| **Unit III** | Hardware GPS & Mapping | Geolocator position streams, OpenStreetMap coordinates |
| **Unit III** | Hardware Sensors (Pedometer, Accelerometer) | Step counter & flip-to-focus screen orientation tracking |
| **Unit III** | Unit, Widget & Integration Testing | 97+ automated tests running in CI/CD pipeline |
| **Unit III** | Multithreading & Dart Isolates | Background aggregation computations via `compute()` |
| **Unit III** | Production Deployment & APK Signing | Gradle release keystore, obfuscated release APK/AAB |

---

## 10. Definition of Done (DoD) & Verification Standards

A feature within OmniLife is considered **Complete** only when all 14 criteria are met:

- [ ] **1. Domain Entity:** Immutable Dart model with `copyWith()`, value equality (`==`), and `hashCode`.
- [ ] **2. Clean Architecture Layering:** Pure use case separating controller from repository.
- [ ] **3. Local Persistence:** SQLite table created with migration script and index.
- [ ] **4. Remote Cloud Persistence:** Firestore document mapper with timeout protection (1500ms).
- [ ] **5. Offline-First Capability:** Tested with airplane mode enabled; updates succeed locally and sync on reconnect.
- [ ] **6. Reactive State:** GetX/BLoC controller with `isLoading`, `errorMessage`, and empty states.
- [ ] **7. Design System Compliance:** Solid surfaces, hairline 1px borders, no gradients, haptic feedback on taps.
- [ ] **8. Form Validation:** Empty checks, length constraints, error banners, and keyboard insets handled.
- [ ] **9. Unit Tests:** Business logic covered with fake/mock repositories.
- [ ] **10. Widget Tests:** UI interactions (tap, enter text, dismiss sheet) verified automatically.
- [ ] **11. Static Analysis:** `flutter analyze` returns zero errors, zero warnings, zero hints.
- [ ] **12. Multi-Platform Check:** Verified on Android (primary) and Chrome Web.
- [ ] **13. Git Cleanliness:** Atomic commit with conventional commit message (`feat(...)`, `fix(...)`).
- [ ] **14. User Documentation:** Route, data schema, and feature documented in `project-plan.md`.

---

## 11. Placement Viva & Technical Defense Handbook

### Core Placement Interview Questions & Answers

#### Q1: "Why did you choose a hybrid of GetX and BLoC instead of sticking to just one?"
> *"In enterprise software engineering, the best tool is chosen for the specific workload. GetX provides rapid, boilerplate-free dependency injection, reactive observable bindings (`Obx`), and lightweight shell routing for standard CRUD modules like Tasks, Notes, and Calendar.*  
> *However, for the AI Life Copilot, we deal with non-deterministic streaming tokens, multi-step tool-calling pipelines, and cancellation events. BLoC's strict unidirectional event-driven finite state machine (`Event -> Bloc -> State`) guarantees formal state traceability, replayability in tests, and zero race conditions during LLM streaming. This demonstrates architectural maturity over dogma."*

#### Q2: "How does OmniLife guarantee zero data loss when the user is in an elevator or subway with no internet?"
> *"OmniLife implements an Offline-First Sync Architecture. When a user creates or edits an item, the mutation is written synchronously to local SQLite storage and immediately updates reactive UI state. Simultaneously, the sync engine attempts a cloud push with a 1500ms timeout guard.*  
> *If the network is unavailable or times out, the mutation payload is appended to an indexed SQLite `sync_queue` table with an operation type (`CREATE`, `UPDATE`, `DELETE`). A connectivity listener and Android `WorkManager` background task continuously monitor network state and replay pending queue operations FIFO with exponential backoff once reconnected."*

#### Q3: "Why did your architecture require SQLite, Firestore, InfluxDB, and MongoDB in the same project?"
> *"Different data structures have fundamentally different storage requirements:*  
> *1. **SQLite (`sqflite`):** Provides instant, sub-millisecond relational queries, ACID guarantees, and foreign keys on device without network dependency.*  
> *2. **Cloud Firestore:** Provides multi-device cloud backup and real-time cross-client synchronization.*  
> *3. **InfluxDB:** Traditional relational and document databases degrade when logging continuous high-frequency time-series data. InfluxDB is purpose-built for sensor streams (accelerometer, pedometer telemetry, focus heart-rate).*  
> *4. **MongoDB:** Unstructured, evolving LLM conversation trees, tool-call arguments, and metadata schemas vary between models (Gemini vs Groq). A flexible document store avoids constant SQLite schema alterations for AI telemetry."*

#### Q4: "What prevented your GetX controllers from being disposed when navigating between screens?"
> *"By default, GetX disposes controllers instantiated on a route when the user navigates away unless explicitly configured. In OmniLife, all foundational controllers (`TaskController`, `CalendarController`, `AuthController`) are registered with `permanent: true` or `fenix: true` inside [initial_binding.dart](file:///d:/Projects/OmniLife/lib/core/bindings/initial_binding.dart) and bound to `GetMaterialApp.initialBinding`.*  
> *Additionally, each route in [app_pages.dart](file:///d:/Projects/OmniLife/lib/app/routes/app_pages.dart) implements an explicit `BindingsBuilder` with idempotency guards (`if (!Get.isRegistered<...>()`), and views implement safe lazy recovery getters, ensuring controllers are never missing even after hot restart or deep-linking."*

---

*OmniLife — Engineered with precision for academic excellence and top-tier placement evaluation.*
