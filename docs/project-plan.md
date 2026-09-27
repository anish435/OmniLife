# OmniLife — Placement-Level Flutter Project Plan

## Project
**OmniLife — AI Personal Life Operating System**

## Goal

Build a production-style Flutter Android application that demonstrates the complete
`23CSE465 Mobile Application Development` syllabus while also showcasing practical
software-engineering skills expected in placements.

OmniLife connects:

- AI Life Copilot
- Tasks & Projects
- Calendar
- Notes
- Habits & Goals
- Finance
- Wellness
- Analytics
- Maps/GPS
- Sensors
- Notifications
- Media/Focus Mode

The key differentiator is that these modules are connected rather than being
independent CRUD screens.

---

# 1. Recommended Development Strategy

## Do NOT build the entire backend first and then the entire frontend.

That approach can work for web applications, but for a first mobile application it
creates a serious risk: the backend contracts, mobile state model, navigation,
offline behavior, permissions, and UI interactions may not match what the Flutter
application actually needs.

Instead use a **hybrid + vertical-slice approach**:

```text
Architecture
     ↓
Backend foundation
     ↓
Flutter foundation
     ↓
FIRST VERTICAL SLICE
Auth → Task → Firebase → Offline → Sync → UI
     ↓
Expand module by module
     ↓
AI integration
     ↓
Device features
     ↓
Testing + optimization
     ↓
Production polish
```

You should still design the backend/data model first, but do not try to finish the
whole backend before writing meaningful Flutter code.

### Rule

For every major feature:

```text
Data model
→ Repository/API
→ Flutter state
→ UI
→ Offline behavior
→ Firebase sync
→ Tests
```

This keeps the project continuously runnable.

---

# 2. Target Architecture

```text
                         OMNILIFE MOBILE APP
                                  │
                     ┌────────────▼────────────┐
                     │ Presentation Layer      │
                     │ Flutter + GetX + BLoC    │
                     └────────────┬────────────┘
                                  │
                     ┌────────────▼────────────┐
                     │ Domain / Use Cases       │
                     │ Business Rules            │
                     └────────────┬────────────┘
                                  │
                     ┌────────────▼────────────┐
                     │ Repository Layer         │
                     └────────────┬────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              ↓                   ↓                   ↓
          SQFLite             Firebase             REST API
          Offline             Cloud                 Weather/
          Cache               Services              News/etc.
              │                   │
              │          ┌────────┼─────────┐
              │          ↓        ↓         ↓
              │        Auth   Firestore   Storage
              │                   │
              │             Realtime DB
              │                   │
              │                  FCM
              │
              └──────────── Sync Engine
                                  │
                         Optional Backend
                                  │
                    ┌─────────────┼─────────────┐
                    ↓             ↓             ↓
                 Gemini          Groq        MongoDB
                    │             │             │
                    └─────────────┼─────────────┘
                                  ↓
                            AI Tool Layer
                                  │
                  ┌───────────────┼────────────────┐
                  ↓               ↓                ↓
                Tasks           Notes           Calendar
                  ↓               ↓                ↓
                Habits          Finance          Wellness
```

Additional infrastructure:

```text
GPS → Maps
Sensors → InfluxDB
Analytics → Firebase Analytics
Crashes → Firebase Crashlytics
Push → Firebase Cloud Messaging
Media → Audio/Video service
```

---

# 3. Phase Overview

| Phase | Focus | Main Result |
|---|---|---|
| 0 | Requirements & architecture | Technical blueprint |
| 1 | Development environment | Stable Flutter project |
| 2 | Backend/data foundation | Firebase + DB architecture |
| 3 | Flutter foundation | App shell + design system |
| 4 | First vertical slice | Auth → Task → Firebase → Offline |
| 5 | Productivity core | Tasks + Calendar + Notes |
| 6 | Personal life modules | Habits + Finance + Wellness |
| 7 | AI platform | AI Copilot + tools |
| 8 | Device/cloud features | FCM + Maps + GPS + Sensors + Media |
| 9 | Analytics + databases | Charts + MongoDB + InfluxDB |
| 10 | Advanced Flutter | BLoC + isolates + animations |
| 11 | Testing + security | Production quality |
| 12 | Deployment + placement polish | Final release + portfolio |

---

# PHASE 0 — Requirements, Architecture & Product Design

## Objective

Freeze the architecture before heavy implementation.

## Tasks

### 0.1 Define modules

Core:

- Dashboard
- AI Copilot
- Tasks
- Calendar
- Notes
- Habits
- Finance
- Wellness
- Analytics

Supporting:

- Authentication
- Notifications
- Maps/GPS
- Sensors
- Media
- Profile/Settings

### 0.2 Define entities

Start with:

```text
User
Task
Project
Subtask
CalendarEvent
Note
Habit
Goal
Expense
Income
WellnessLog
AIConversation
AIMessage
Attachment
Notification
Location
SensorReading
```

### 0.3 Define relationships

Example:

```text
User
 ├── Projects
 ├── Tasks
 ├── Events
 ├── Notes
 ├── Habits
 ├── Expenses
 ├── WellnessLogs
 └── AIConversations
```

### 0.4 Define feature contracts

For every module document:

- Input
- Output
- Database model
- Repository methods
- Controller/BLoC state
- Error states
- Loading states
- Offline behavior

## Deliverable

`docs/architecture.md`

---

# PHASE 1 — Development Environment & Repository

## Objective

Create the actual development foundation.

## Tasks

- Create Flutter project
- Configure Android application ID
- Configure Git
- Create GitHub repository
- Set up branch strategy
- Configure linting/formatting
- Configure environment variables
- Add `.gitignore`
- Add README
- Run `flutter doctor`
- Run clean Android build
- Test on physical Android device

## Recommended Git branches

```text
main
develop
feature/*
fix/*
```

Never develop everything directly on `main`.

## Deliverable

A blank Flutter application that builds and runs reliably.

---

# PHASE 2 — Backend & Data Foundation

This is where your instinct to start with the backend is useful.

But build the **foundation**, not the complete backend.

## 2.1 Firebase

Use:

- Firebase Authentication
- Cloud Firestore
- Realtime Database
- Cloud Storage
- Firebase Cloud Messaging
- Firebase Analytics
- Firebase Crashlytics

The supplied Firebase guide recommends using FlutterFire CLI and
`flutterfire configure` to connect the Flutter application to Firebase.
It also specifies initializing Firebase before `runApp`. 

## 2.2 Firebase setup order

```text
Firebase project
     ↓
FlutterFire CLI
     ↓
flutterfire configure
     ↓
firebase_core
     ↓
Firebase.initializeApp()
     ↓
Authentication
     ↓
Firestore
     ↓
Storage
     ↓
Realtime Database
     ↓
FCM
     ↓
Analytics
     ↓
Crashlytics
```

## 2.3 Firestore structure

Recommended:

```text
users/{uid}

users/{uid}/tasks/{taskId}
users/{uid}/projects/{projectId}
users/{uid}/events/{eventId}
users/{uid}/notes/{noteId}
users/{uid}/habits/{habitId}
users/{uid}/goals/{goalId}
users/{uid}/expenses/{expenseId}
users/{uid}/wellness/{logId}
users/{uid}/conversations/{conversationId}
```

This keeps user-owned data naturally scoped.

## 2.4 Security

Never leave production Firestore in open test mode.

The supplied Firebase guide explicitly recommends setting proper Firestore security
rules before production and not committing API keys/secrets to Git.

Example conceptual rule:

```text
User can read/write only their own documents.
```

## 2.5 SQFLite schema

Create local tables for:

```text
tasks
projects
events
notes
habits
expenses
sync_queue
```

## 2.6 Repository interfaces

Example:

```dart
abstract class TaskRepository {
  Future<List<Task>> getTasks();
  Future<Task> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);
  Future<void> completeTask(String id);
}
```

Then implementations:

```text
TaskRepository
     │
     ├── LocalTaskDataSource
     └── FirebaseTaskDataSource
```

## Deliverable

Backend/data foundation + database schemas + repository contracts.

---

# PHASE 3 — Flutter Application Foundation

## Objective

Build the reusable Flutter layer before implementing all screens.

## Create

```text
lib/
├── app/
│   ├── app.dart
│   ├── routes/
│   └── theme/
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── utils/
│   └── services/
│
├── data/
│   ├── models/
│   ├── datasources/
│   └── repositories/
│
├── domain/
│   ├── entities/
│   └── usecases/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── tasks/
│   ├── calendar/
│   ├── notes/
│   ├── habits/
│   ├── finance/
│   ├── wellness/
│   ├── analytics/
│   ├── ai/
│   ├── maps/
│   ├── sensors/
│   └── media/
│
└── shared/
    ├── widgets/
    ├── dialogs/
    └── animations/
```

## Build design system

Create:

- Colors
- Typography
- Spacing
- Radius
- Shadows
- Buttons
- Cards
- Text fields
- Chips
- Dialogs
- Bottom sheets
- Empty states
- Loading states
- Error states

## Flutter concepts deliberately demonstrated

- MaterialApp
- Scaffold
- AppBar
- FAB
- Container
- Row
- Column
- Stack
- ListView
- ListTile
- GridView
- GestureDetector
- InkWell
- TextField
- Navigator/routes
- Dialogs
- StatelessWidget
- StatefulWidget
- Themes

## Deliverable

Professional application shell with reusable components.

---

# PHASE 4 — FIRST VERTICAL SLICE

This phase is extremely important.

Do not move forward until this works end-to-end.

## Implement

```text
Register
  ↓
Firebase Authentication
  ↓
Create user profile
  ↓
Home
  ↓
Create Task
  ↓
GetX Controller
  ↓
Task Repository
  ↓
SQFLite
  ↓
Firebase Firestore
  ↓
Task appears on dashboard
```

Then:

```text
Internet OFF
    ↓
Create Task
    ↓
SQFLite
    ↓
Task remains available
    ↓
Internet ON
    ↓
Sync queue
    ↓
Firestore
```

## Why this phase exists

It validates the most important architectural assumption before you build ten modules.

If this works, the rest of OmniLife becomes controlled repetition rather than
architectural guessing.

## Deliverable

One production-quality vertical feature.

---

# PHASE 5 — PRODUCTIVITY CORE

Build the three most important modules.

## 5.1 Tasks

Features:

- CRUD
- Priority
- Due date/time
- Reminder
- Category
- Tags
- Subtasks
- Search
- Filter
- Sort
- Completion
- Recurrence

## 5.2 Calendar

Features:

- Month
- Week
- Day agenda
- Event CRUD
- Date picker
- Time picker
- Recurrence
- Reminder
- Location

## 5.3 Notes

Features:

- CRUD
- Tags
- Categories
- Pin
- Archive
- Search
- Attach image/file
- Checklist

## Cross-module workflows

```text
Note
 ↓
Action items
 ↓
Tasks
 ↓
Calendar
 ↓
Reminder
```

and:

```text
Task deadline
 ↓
Calendar
 ↓
Dashboard
```

## Deliverable

OmniLife becomes a genuinely usable productivity application.

---

# PHASE 6 — PERSONAL LIFE MODULES

## 6.1 Habits

- Habit CRUD
- Frequency
- Streak
- Calendar history
- Completion percentage
- Goals

## 6.2 Finance

- Income
- Expenses
- Categories
- Budgets
- Recurring expenses
- Monthly summaries

## 6.3 Wellness

- Water
- Sleep
- Exercise
- Mood
- Wellness goals

Keep wellness non-medical.

## 6.4 Dashboard

Combine:

```text
Tasks
Calendar
Habits
Finance
Wellness
```

into one daily overview.

## Deliverable

OmniLife now represents a connected personal life system.

---

# PHASE 7 — AI LIFE COPILOT

Only start this after the underlying data models work.

## 7.1 AI provider abstraction

Do not hardcode the application around one provider.

```dart
abstract class AIProvider {
  Future<AIResponse> generate(AIRequest request);
}
```

Implement:

```text
GeminiProvider
GroqProvider
```

The application should be able to switch provider through configuration.

## 7.2 AI service

```text
AIController
    ↓
AIService
    ↓
AIProvider
```

## 7.3 Tool system

Define tools:

```text
create_task
update_task
complete_task
create_event
create_note
create_habit
add_expense
search_notes
get_today_schedule
get_productivity_summary
```

## 7.4 AI flow

```text
User
 ↓
AI Chat
 ↓
Intent
 ↓
Tool selection
 ↓
Tool arguments
 ↓
Validation
 ↓
User confirmation
 ↓
Repository
 ↓
Database
```

AI must not blindly modify important user data.

## 7.5 AI features

### Ask OmniLife

General conversational assistant.

### Plan My Day

Uses:

- Tasks
- Calendar
- Deadlines
- Available time

### Note Summarizer

### Note → Tasks

### AI Study Assistant

- Explain
- Summarize
- Quiz
- Flashcards

### Weekly Life Review

Uses:

- Productivity
- Habits
- Expenses
- Calendar

## Deliverable

AI that interacts with the application rather than a standalone chatbot.

---

# PHASE 8 — DEVICE + CLOUD FEATURES

Now implement the remaining syllabus-heavy mobile features.

## 8.1 Firebase Cloud Messaging

Use for:

- Task reminders
- Habit reminders
- Calendar reminders
- AI weekly review

The supplied Firebase guide includes FCM permission/token setup, foreground
listeners and a top-level background message handler.

Test notifications on a real Android device.

## 8.2 Cloud Storage

Use for:

- Profile image
- Note attachments
- Document attachments

## 8.3 Realtime Database

Use for:

- Real-time AI conversation status
- Presence/status if needed
- Real-time activity stream

Do not use it for everything; Firestore remains the primary application database.

## 8.4 Maps + GPS

Implement:

- Current location
- Location picker
- Event location
- Nearby places
- Distance

## 8.5 Sensors

Implement one meaningful use case:

```text
Sensor data
 ↓
Focus/activity tracking
 ↓
Local processing
 ↓
InfluxDB
 ↓
Analytics
```

## 8.6 Media

Build:

### Focus Mode

- Music playback
- Video playback
- Play/pause
- Seek
- Timer
- Session completion

This gives the Unit II media requirements a real purpose.

---

# PHASE 9 — MongoDB + InfluxDB + Analytics

## MongoDB

Do not duplicate Firebase.

Use MongoDB for:

```text
AI conversations
AI tool execution logs
Flexible AI context metadata
```

Architecture:

```text
Flutter
 ↓
Backend API
 ↓
MongoDB
```

## InfluxDB

Use for time-series information:

```text
sensor readings
focus sessions
activity
wellness measurements
```

## Analytics dashboard

Build:

- Task completion trend
- Habit consistency
- Expense trend
- Focus sessions
- Wellness trend

Use:

- Line charts
- Bar charts
- Pie/donut charts
- Progress indicators

## Deliverable

A real analytics system with a justified database architecture.

---

# PHASE 10 — ADVANCED FLUTTER

This phase exists specifically to showcase Flutter skill.

## BLoC

Use BLoC for AI conversation/remote dashboard.

Example:

```text
AIEvent
 ↓
Bloc
 ↓
AIState

Initial
Loading
Streaming
Success
Error
```

## GetX

Use for application-level state:

- Auth
- Tasks
- Notes
- Theme
- Profile

## Isolates

Use `compute()` / isolates for:

- Large JSON parsing
- Analytics calculations
- Sensor-data processing
- Large local-search operations

## Animations

Implement deliberately:

### Navigation

- Fade
- Slide
- Shared-axis style transitions

### Dashboard

- Animated statistics
- Progress animations

### Tasks

- Completion animation
- Swipe actions

### AI

- Streaming text effect
- Typing indicator

### Habits

- Streak animation

### Charts

- Animated entry

### Global

- Skeleton loading
- Shimmer
- Pull-to-refresh
- Expand/collapse
- Bottom-sheet transitions
- Theme transitions

## Deliverable

The application should feel like a polished commercial mobile application.

---

# PHASE 11 — TESTING, SECURITY & PERFORMANCE

Do not leave testing until the final day.

## Unit tests

Test:

- Task use cases
- Validators
- AI tool parser
- Expense calculations
- Habit calculations
- Repository behavior

## Widget tests

Test:

- Login
- Task creation
- Task completion
- Note creation
- Theme switching

## Integration tests

Test:

```text
Register
 ↓
Login
 ↓
Create task
 ↓
Task appears
 ↓
Logout
 ↓
Login
 ↓
Task still exists
```

## Offline test

```text
Disable internet
 ↓
Create task
 ↓
Restart app
 ↓
Task exists
 ↓
Reconnect
 ↓
Firebase sync
```

## Security

Verify:

- Authentication required
- Users cannot read another user's data
- Storage access is controlled
- API keys are not inside Git
- Secrets are environment/backend controlled

The supplied Firebase guide specifically warns against leaving Firestore in test mode
and against committing API keys/secrets.

## Crashlytics

Intentionally test error reporting in a controlled development environment.

## Analytics

Track meaningful events:

```text
sign_up
task_created
task_completed
note_created
ai_query
ai_tool_executed
habit_completed
expense_added
focus_session_completed
```

## Performance

Check:

- Startup time
- List rendering
- Image loading
- Database queries
- AI response latency
- Memory usage
- Animation smoothness

---

# PHASE 12 — DEPLOYMENT + PLACEMENT POLISH

## Android

Produce:

```text
debug APK
release APK
release AAB
```

## App polish

Add:

- App icon
- Splash screen
- Proper permissions
- Privacy information
- Error messages
- Empty states
- Loading states
- Offline indicator
- Network retry
- Accessibility labels

## GitHub

README should contain:

1. Project overview
2. Architecture diagram
3. Screenshots
4. Feature list
5. Technology stack
6. Firebase architecture
7. AI architecture
8. Database architecture
9. Setup instructions
10. Testing
11. Demo video
12. Future improvements

---

# 4. Recommended Development Order Inside Claude Code

Claude Code should NOT be asked:

> "Build the whole OmniLife application."

That produces a large amount of unverified code.

Instead use controlled implementation cycles.

## Cycle

```text
1. Give Claude one feature
2. Ask it to inspect existing architecture
3. Implement
4. Run formatter
5. Run analyzer
6. Run tests
7. Run Flutter app
8. Manually verify
9. Commit
10. Move to next feature
```

## Example prompt

```text
Implement the Task feature using the existing OmniLife architecture.

Before coding:
1. Inspect the current repository.
2. Do not change architecture unnecessarily.
3. Follow existing models, repositories and GetX patterns.
4. Implement Task model, local datasource, Firebase datasource,
   repository, controller and UI.
5. Add loading/error/empty states.
6. Add unit tests for the repository/use cases.
7. Run dart format.
8. Run flutter analyze.
9. Run relevant tests.
10. Report every changed file and any remaining issue.

Do not implement unrelated features.
```

This is much safer than giving Claude a 500-line "build everything" prompt.

---

# 5. Definition of Done

A feature is NOT finished merely because the screen appears.

A feature is complete only when:

```text
UI
✓
State management
✓
Validation
✓
Repository
✓
Local persistence
✓
Cloud persistence where applicable
✓
Loading state
✓
Error state
✓
Empty state
✓
Offline behavior
✓
Tests
✓
Analytics event where appropriate
✓
Crash handling
✓
Animation/polish
✓
Manual device verification
```

---

# 6. Three Milestones That Must Never Be Skipped

## Milestone A — End of Phase 4

You can:

```text
Register
Login
Create Task
Save locally
Save to Firebase
Go offline
Restart app
Reconnect
Sync
```

If this does not work, stop and fix architecture.

## Milestone B — End of Phase 7

You can say:

> "OmniLife's AI can understand natural language and safely interact with the user's tasks, notes and calendar."

## Milestone C — End of Phase 12

You can say:

> "This is a production-style Flutter application with Firebase,
offline persistence, AI tool calling, REST APIs, multiple database
technologies, device APIs, testing, analytics and deployment."

---

# 7. Syllabus Coverage Checklist

## Unit I

- [ ] Dart
- [ ] MaterialApp
- [ ] Scaffold
- [ ] AppBar
- [ ] FAB
- [ ] Text
- [ ] Center
- [ ] Padding
- [ ] Hot reload/restart
- [ ] Containers
- [ ] Asset images
- [ ] Network images
- [ ] Icons
- [ ] Row/Column
- [ ] ListView
- [ ] ListTile
- [ ] GestureDetector
- [ ] InkWell
- [ ] Stateless widgets
- [ ] Stateful widgets
- [ ] State management
- [ ] Navigator/routes
- [ ] TextField
- [ ] Themes
- [ ] Custom fonts
- [ ] GridView
- [ ] Stack
- [ ] AlertDialog

## Unit II

- [ ] Advanced widgets
- [ ] Chips
- [ ] Video
- [ ] Music
- [ ] Date picker
- [ ] Time picker
- [ ] Future
- [ ] async
- [ ] await
- [ ] HTTP
- [ ] REST API
- [ ] Model classes
- [ ] JSON parsing
- [ ] Remote data
- [ ] BLoC
- [ ] GetX
- [ ] Charts
- [ ] Push notifications
- [ ] Animations

## Unit III

- [ ] Firebase
- [ ] SQFLite
- [ ] InfluxDB
- [ ] MongoDB
- [ ] Maps
- [ ] GPS
- [ ] Sensors
- [ ] Testing
- [ ] Deployment
- [ ] Multithreading/isolate processing

---

# 8. Final Product Structure

The final application navigation should look approximately like:

```text
Splash
 ↓
Onboarding
 ↓
Authentication
 ↓
HOME
 ├── AI Copilot
 ├── Tasks
 │    └── Projects
 ├── Calendar
 ├── Notes
 ├── Habits
 ├── Finance
 ├── Wellness
 ├── Analytics
 ├── Focus Mode
 │    ├── Music
 │    └── Video
 ├── Maps
 │    └── GPS
 └── Profile
      └── Settings
```

---

# 9. Final Engineering Philosophy

OmniLife should demonstrate three things simultaneously:

## 1. Flutter skill

```text
Widgets
Layouts
Animations
State
Navigation
Forms
Charts
Media
Device APIs
Performance
```

## 2. Mobile engineering skill

```text
Offline-first
Local database
Cloud synchronization
Notifications
Permissions
GPS
Sensors
Testing
Deployment
```

## 3. Modern software engineering

```text
Clean architecture
Repositories
Dependency boundaries
AI tool calling
Backend APIs
Firebase
MongoDB
InfluxDB
Security
Observability
CI/CD-ready Git workflow
```

The project should therefore be judged by:

> **How well the parts work together**, not by how many screens exist.

The central demonstration should always be:

```text
USER
 ↓
Flutter UI
 ↓
State Management
 ↓
Use Case
 ↓
Repository
 ↓
Local / Cloud Data
 ↓
AI / External Service
 ↓
Result
 ↓
UI Update
```

That is the architecture that turns OmniLife from a college CRUD project into a
placement-level Flutter engineering project.
