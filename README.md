# OmniLife — Proof of Concept (PoC) & Complete Feature Architecture

## 1. Project Overview

**OmniLife** is an AI-powered personal productivity and life-management mobile application built with Flutter.

The core idea is not simply to place many utilities inside one app. OmniLife connects those utilities so that information can flow between modules:

> **Capture → Understand → Plan → Act → Track → Learn**

Examples:

- A note can be converted into tasks.
- Tasks can be scheduled on the calendar.
- Calendar events can trigger reminders.
- Completed tasks contribute to productivity analytics.
- Expenses contribute to financial analytics.
- AI can summarize the user's activity and provide recommendations.

### Primary objective

Build a scalable mobile application that demonstrates the major concepts in the Mobile Application Development syllabus while providing a realistic foundation for AI, cloud, offline, location, notification, and analytics features.

---

# 2. Project Scope

OmniLife is divided into the following major domains:

1. Authentication & Onboarding
2. Home Dashboard
3. AI Assistant
4. Task Management
5. Calendar & Smart Scheduling
6. Notes & Knowledge Management
7. Habit Tracking
8. Expense & Finance Management
9. Health & Wellness
10. Notifications & Reminders
11. Analytics & Insights
12. Maps & Location Services
13. Document Vault
14. News & External Information
15. Community
16. Messaging
17. Profile & Settings
18. Offline & Synchronization
19. Backend & Cloud Services
20. Testing, Security & Deployment

Not every module needs to be implemented in the first release. The architecture should support future expansion.

---

# 3. Feature Architecture

## 3.1 Authentication & Onboarding

### Screens

- Splash Screen
- Onboarding 1
- Onboarding 2
- Onboarding 3
- Login
- Register
- Forgot Password
- OTP Verification (optional)
- Account Setup

### Features

- Email/password authentication
- Google authentication (optional)
- Profile creation
- Preference selection
- Theme preference
- Notification permission
- Location permission

### Future

- Biometric login
- Passkeys
- Multi-device session management

---

# 4. Home Dashboard

The Home screen is the central control center.

### Header

- Personalized greeting
- Current date
- Profile avatar
- Notification icon

### AI Command Bar

> "Ask OmniLife anything..."

Examples:

- "What should I do today?"
- "Create a task for tomorrow."
- "Summarize my notes."
- "How much did I spend this month?"

### Dashboard cards

- Today's Progress
- Today's Tasks
- Upcoming Events
- Habit Progress
- Expense Summary
- Weather
- AI Insight
- Reminders

### Quick Actions

- Add Task
- Add Event
- Add Note
- Add Expense
- Add Habit
- Ask AI

### Personalization

The dashboard should eventually adapt to the user's selected profile/use case.

---

# 5. Task Management

## Task List

- All
- Today
- Upcoming
- Completed
- Overdue

## Create Task

Fields:

- Title
- Description
- Category
- Priority
- Due Date
- Due Time
- Reminder
- Repeat
- Subtasks
- Attachments

## Task operations

- Create
- Read
- Update
- Delete
- Complete
- Duplicate
- Archive

## Interaction

- Tap → details
- Swipe → actions
- Long press → edit/delete
- Checkbox → complete

## AI integration

### Natural-language task creation

User:

> "Submit my DBMS assignment tomorrow at 5 PM."

AI converts it into a structured task.

### AI prioritization

AI analyzes:

- Deadline
- Priority
- Estimated effort
- Dependencies
- Calendar availability

and suggests an order.

### Notes → Tasks

AI detects action items in notes and offers to convert them into tasks.

---

# 6. Calendar & Smart Scheduling

## Calendar

- Month view
- Week view
- Day agenda
- Event details
- Create event
- Edit event
- Delete event

## Event fields

- Title
- Description
- Date
- Start time
- End time
- Location
- Reminder
- Repeat

## Smart Scheduling

Future AI feature:

> "I need to study DBMS for 3 hours before Friday."

AI checks:

- Existing calendar events
- Tasks
- Available time

and suggests schedule blocks.

---

# 7. Notes & Knowledge Management

## Notes

- Create
- Edit
- Delete
- Pin
- Archive
- Search
- Categories
- Tags

## Note types

- Text note
- Checklist
- Study note
- Meeting note
- Idea
- Personal note

## Rich content — future

- Bold
- Italic
- Lists
- Images
- Attachments
- Voice notes

## AI capabilities

### Summarize

Convert long notes into concise summaries.

### Explain

Explain selected concepts.

### Quiz generation

Generate questions from notes.

### Note → Task

Extract actionable items.

### Semantic search

Example:

> "Where did I write about database normalization?"

AI searches notes by meaning rather than only exact keywords.

---

# 8. Habit Tracker

## Features

- Create habit
- Daily completion
- Streaks
- Weekly/monthly statistics
- Habit categories
- Reminder
- Goal frequency

Examples:

- Study
- Exercise
- Reading
- Water
- Meditation

## Dashboard

- Current streak
- Completion percentage
- Weekly chart
- Monthly consistency

## AI

AI can suggest habits based on goals and existing behavior.

---

# 9. Expense & Finance Management

## Expense features

- Add income
- Add expense
- Categories
- Payment method
- Date
- Notes
- Recurring expenses

## Categories

- Food
- Transport
- Education
- Shopping
- Entertainment
- Bills
- Other

## Analytics

- Daily spending
- Weekly spending
- Monthly spending
- Category breakdown
- Income vs expenses
- Savings

## AI

Examples:

> "How much did I spend on food this month?"

> "Where can I reduce my spending?"

> "Compare this month with last month."

AI should use stored user data rather than inventing financial information.

---

# 10. Health & Wellness

Keep this module lightweight in the academic MVP.

## Features

- BMI calculator
- Water tracking
- Exercise logging
- Sleep logging
- Medicine reminders
- Basic wellness goals

## Device integration — future

- Step count
- Accelerometer
- Health platform integration

## Important

AI health functionality should be framed as general wellness information, not medical diagnosis.

---

# 11. Notifications & Reminders

## Notifications

- Task reminders
- Event reminders
- Habit reminders
- Medicine reminders
- Expense reminders
- AI-generated reminders

## Technologies

- Local notifications
- Firebase Cloud Messaging

## Notification flow

```text
Task/Event/Habit
       ↓
Reminder Scheduler
       ↓
Notification Service
       ↓
User Device
```

---

# 12. Analytics & Insights

Central analytics dashboard.

## Productivity

- Tasks completed
- Completion percentage
- Overdue tasks
- Productivity trend

## Habits

- Streaks
- Consistency
- Completion rate

## Finance

- Spending
- Income
- Savings
- Category distribution

## Charts

- Line chart
- Bar chart
- Pie/donut chart
- Progress indicators

## AI Insights

Examples:

> "You complete most tasks in the evening."

> "Your food expenses increased compared with the previous month."

Insights should be generated from actual stored data.

---

# 13. Maps & Location

## Features

- Current location
- Nearby places
- Location picker
- Event location
- Directions

Possible nearby services:

- Hospitals
- Pharmacies
- Gyms
- Restaurants
- ATMs
- Petrol stations

## Technology

- GPS
- Google Maps
- Geolocation APIs

---

# 14. Document Vault

Optional but useful expansion.

## Features

- Upload document
- View document
- Delete
- Categorize
- Search

Categories:

- Certificates
- IDs
- Receipts
- Academic documents
- Personal documents

Future AI:

- OCR
- Document summarization
- Automatic categorization

---

# 15. News & External Information

Optional module.

## Features

- Technology news
- Education news
- Business news
- Personalized feed
- Bookmark articles

## REST API concepts

- HTTP requests
- JSON parsing
- Model classes
- Loading states
- Error handling

---

# 16. Community

Optional advanced module.

## Features

- Posts
- Comments
- Likes
- Categories
- Search
- Report content

Possible communities:

- Study
- Technology
- Productivity
- Fitness
- Projects

Firebase can be used for real-time updates.

---

# 17. Messaging

Optional advanced module.

## Features

- One-to-one chat
- Group chat
- Text messages
- Image/file sharing
- Message timestamps

Future AI:

- Conversation summarization
- Smart reply suggestions

---

# 18. Profile & Settings

## Profile

- Name
- Email
- Profile picture
- Bio
- Statistics
- Achievements

## Settings

- Light/Dark/System theme
- Notifications
- Language
- Privacy
- Data export
- Backup/sync
- About
- Help & Support
- Logout

---

# 19. AI Architecture

AI should be an enhancement layer across OmniLife.

## AI Assistant

```text
User
  ↓
AI Chat Interface
  ↓
AI Service
  ↓
Intent Detection
  ↓
Context Retrieval
  ↓
OmniLife Module
  ↓
Action / Answer
```

### Example

User:

> "What should I focus on today?"

```text
AI
 ↓
Read Tasks
 ↓
Read Calendar
 ↓
Read Habits
 ↓
Check Deadlines
 ↓
Generate Recommendation
```

### AI capabilities

1. General chatbot
2. Natural-language task creation
3. Note summarization
4. Note-to-task conversion
5. Quiz generation
6. Smart scheduling
7. Productivity insights
8. Expense analysis
9. Personalized recommendations
10. Voice input (future)

### Important architecture principle

The AI must not directly modify important user data without confirmation.

Example:

```text
AI: I found 3 tasks in your note.

☑ Submit report
☑ Meet project team
☑ Complete database module

[Add Tasks] [Cancel]
```

---

# 20. Data Architecture

## Local

Use **SQFLite** for:

- Cached tasks
- Notes
- Calendar data
- Habits
- Expenses
- Offline queue

## Cloud

Use **Firebase** for:

- Authentication
- Firestore
- Cloud synchronization
- Push notifications
- File storage

## Optional backend

Use Node.js/FastAPI with MongoDB if a dedicated backend is required.

---

# 21. Suggested Firebase Collections

```text
users
  └── userId
      ├── profile
      ├── preferences

tasks
events
notes
habits
expenses
health_logs
notifications
ai_conversations
documents
community_posts
messages
```

Every user-owned document should contain an appropriate `userId` or be stored under a user-specific path.

---

# 22. Flutter Architecture

Recommended structure:

```text
lib/
│
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── routes/
│   └── theme/
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── utils/
│   └── services/
│
├── data/
│   ├── models/
│   ├── local/
│   ├── remote/
│   └── repositories/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── tasks/
│   ├── calendar/
│   ├── notes/
│   ├── habits/
│   ├── expenses/
│   ├── health/
│   ├── ai/
│   ├── analytics/
│   ├── maps/
│   ├── notifications/
│   ├── profile/
│   └── settings/
│
└── shared/
    ├── widgets/
    ├── dialogs/
    └── components/
```

Use feature-based organization so individual modules can evolve independently.

---

# 23. State Management

Use **GetX** for the academic project because it is relatively straightforward to demonstrate.

Suggested controllers:

```text
AuthController
HomeController
TaskController
CalendarController
NotesController
HabitController
ExpenseController
AIController
NotificationController
ProfileController
```

For each feature:

```text
UI
 ↓
Controller
 ↓
Repository
 ↓
Local / Remote Data Source
```

---

# 24. UI Design System

## Brand

OmniLife:

**Indigo + Teal**

AI:

**Violet**

## Light Mode

```text
Background       #F8F9FC
Surface          #FFFFFF
Primary          #6366F1
Primary Dark     #4F46E5
Secondary        #14B8A6
AI               #8B5CF6
Text             #111827
Secondary Text   #64748B
Border           #E2E8F0
Success          #22C55E
Warning          #F59E0B
Error            #EF4444
```

## Dark Mode

```text
Background       #0F172A
Surface          #1E293B
Elevated         #273449
Primary          #818CF8
Primary Dark     #6366F1
Secondary        #2DD4BF
AI               #A78BFA
Text             #F8FAFC
Secondary Text   #94A3B8
Border           #334155
Success          #4ADE80
Warning          #FBBF24
Error            #F87171
```

Use AI gradient sparingly:

```text
#6366F1 → #8B5CF6
```

---

# 25. MVP Scope

Do NOT implement every feature immediately.

## MVP — Phase 1

Focus on Flutter fundamentals.

### Implement

- Splash
- Onboarding
- Login/Register UI
- Home Dashboard
- Tasks
- Notes
- Calendar
- Profile
- Settings
- Light/Dark Theme
- Bottom Navigation
- Navigation Drawer
- Mock data
- Forms
- Dialogs
- Search
- Basic state management

### Main navigation

```text
Home
Tasks
Calendar
Notes
Profile
```

---

# 26. Phase 2

Focus on advanced Flutter and networking.

### Add

- AI Assistant
- AI Task Creation
- AI Note Summarization
- REST API
- Weather
- News
- JSON parsing
- Expense module
- Habit module
- Charts
- GetX
- Push notifications
- Animations

---

# 27. Phase 3

Focus on Unit III.

### Add

- Firebase Authentication
- Firestore
- Firebase Storage
- SQFLite
- Offline mode
- Cloud synchronization
- Google Maps
- GPS
- Sensors
- Device permissions
- Testing
- Release build
- Deployment

---

# 28. Syllabus Mapping

| Syllabus Topic | OmniLife Feature |
|---|---|
| Dart | Entire application |
| Widgets | All screens |
| MaterialApp | App root |
| Scaffold | Main screens |
| AppBar | All modules |
| FAB | Add Task/Note/Event |
| Text | All UI |
| Center/Padding | Layout |
| Container | Cards/UI |
| Images | Profile/Documents |
| Network Images | News |
| Icons | Navigation |
| Row/Column | Layout |
| ListView | Tasks/Notes |
| ListTile | Tasks/Events |
| Gesture Detection | Task/Note actions |
| InkWell | Cards/buttons |
| Stateless/Stateful | Screens/widgets |
| State Management | GetX |
| Navigator/Routes | App navigation |
| TextField | Forms/Search |
| Themes | Light/Dark |
| Custom Fonts | Design system |
| GridView | Quick Actions/Categories |
| Stack | Dashboard/overlays |
| AlertDialog | Delete/confirmation |
| Chips | Categories/tags |
| Date Picker | Tasks/Events |
| Time Picker | Tasks/Events |
| Future | API/Firebase operations |
| Async/Await | API/database |
| HTTP | Weather/News/AI |
| REST API | External services |
| Model Class | API/Firebase models |
| JSON Parsing | API responses |
| Remote Data | News/Weather |
| BLoC/GetX | GetX state management |
| Charts | Analytics |
| Push Notifications | Reminders |
| Animations | UI transitions |
| Firebase | Auth/Cloud |
| SQFLite | Offline storage |
| InfluxDB | Optional sensor/time-series data |
| MongoDB | Optional custom backend |
| Maps | Location services |
| GPS | Current/nearby location |
| Sensors | Activity features |
| Testing | Unit/widget/integration tests |
| Deployment | Android release |

---

# 29. MVP User Flow

```text
Splash
  ↓
Onboarding
  ↓
Login / Register
  ↓
Home Dashboard
  │
  ├── Tasks
  │    ├── Task List
  │    ├── Create Task
  │    └── Task Details
  │
  ├── Calendar
  │    ├── Calendar View
  │    ├── Create Event
  │    └── Event Details
  │
  ├── Notes
  │    ├── Notes List
  │    ├── Create Note
  │    └── Note Details
  │
  └── Profile
       ├── Settings
       ├── Theme
       └── About
```

---

# 30. Extended User Flow

```text
                         ┌─────────────┐
                         │   Splash    │
                         └──────┬──────┘
                                ↓
                         ┌─────────────┐
                         │ Onboarding  │
                         └──────┬──────┘
                                ↓
                      ┌──────────────────┐
                      │ Login / Register │
                      └────────┬─────────┘
                               ↓
                    ┌─────────────────────┐
                    │   HOME DASHBOARD    │
                    └──────────┬──────────┘
                               │
       ┌────────────┬──────────┼───────────┬────────────┐
       ↓            ↓          ↓           ↓            ↓
     Tasks       Calendar     Notes      Habits      Expenses
       │            │          │           │            │
       └────────────┴──────────┼───────────┴────────────┘
                               ↓
                         ┌─────────────┐
                         │     AI      │
                         │  Assistant  │
                         └──────┬──────┘
                                │
              ┌─────────────────┼─────────────────┐
              ↓                 ↓                 ↓
          Tasks/Actions       Notes           Analytics
              │                 │                 │
              └─────────────────┼─────────────────┘
                                ↓
                         Notifications
                                ↓
                         User Activity
                                ↓
                          Analytics
```

---

# 31. Key Product Principle

OmniLife should NOT feel like:

> "15 unrelated features inside one application."

It should feel like:

> **"One personal operating system where different parts of life are connected."**

The strongest cross-module workflows are:

### Workflow 1 — Note to Task

```text
Note
 ↓
AI extracts action items
 ↓
User confirms
 ↓
Tasks
 ↓
Calendar
 ↓
Reminder
```

### Workflow 2 — Smart Planning

```text
User Request
 ↓
AI
 ↓
Tasks + Calendar + Existing Commitments
 ↓
Suggested Schedule
 ↓
User Confirmation
```

### Workflow 3 — Personal Insights

```text
Tasks + Habits + Expenses + Calendar
                    ↓
                 AI/Analytics
                    ↓
              Weekly Insight
```

These workflows should become the defining feature of OmniLife.

---

# 32. PoC Success Criteria

The PoC should demonstrate that:

- A user can navigate through the application.
- A user can create and manage tasks.
- A user can create and manage notes.
- A user can view and create calendar events.
- The dashboard summarizes user activity.
- Modules use shared data concepts.
- The application supports Light/Dark mode.
- The architecture is ready for Firebase and SQFLite.
- AI can later interact with tasks and notes.
- The application can be expanded in Phase 2 and Phase 3 without redesigning the entire codebase.

The PoC is successful when the application demonstrates the **architecture and core user experience**, not when every planned feature has been implemented.
