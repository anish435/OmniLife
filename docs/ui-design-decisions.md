# OmniLife — UI Design Decisions & Architecture Guide

> **Review 1 Presentation Reference (Rubric E3)**  
> This document details the visual and design-system decisions behind OmniLife so every team member can articulate the rationale for their module during evaluation.

---

## 1. Palette Rationale (Editorial Warmth vs. AI Slop)
* **Accent Terracotta (`#E2725B` Dark / `#C9553D` Light):** Chosen to provide human, editorial warmth reminiscent of natural ceramic and print publishing, deliberately avoiding generic AI-generated indigo, purple, and neon gradients.
* **Surfaces:**
  * **Dark Mode:** Deep charcoal background (`#101214`), dark surface (`#171A1D`), raised cards (`#1E2226`), and subtle 1px hairlines (`#2A2F34`). Pure contrast with zero muddy blue-slate tint.
  * **Light Mode:** Warm tactile paper (`#F6F3EE`), crisp card surfaces (`#FFFFFF`), raised elements (`#FBF9F5`), and warm hairline borders (`#E4DFD6`).
* **Muted Module Hues (Tint & Left-Bar Accents Only):**  
  * Tasks: `#E2725B` (Terracotta) | Calendar: `#6FA3C7` (Sky Slate) | Notes: `#C9A86A` (Amber Ochre)
  * Habits: `#8DB596` (Sage Green) | Finance: `#7FB3AC` (Muted Teal) | Wellness: `#B592B8` (Soft Plum)
* **Contrast & Hierarchy:** All text passes WCAG AA contrast (≥ 4.5:1) in both light and dark modes. Surfaces rely on tonal steps and 1px hairlines rather than heavy drop shadows.

---

## 2. Typography & Numerical Rhythm
* **Type Scale:** Display 32/600 (Greetings/Hero), Title 20/600, Body 15/400, Caption 12/400.
* **Section Labels:** 12px uppercase with `+0.8` tracking in tertiary tone (`#6B6C68` dark / `#9A968C` light) to clearly delineate modules without visual weight.
* **Tabular Figures:** `FontFeature.tabularFigures()` applied to all metrics, clock times, currency amounts, and dates so columns never jitter during live updates.

---

## 3. Spacing, Layout & Responsive Grid
* **4px Grid System:** Page gutter 16px (mobile), 24px (tablet), 32px (web/desktop). Section gaps fixed at 24px.
* **Minimum Row Height:** 48px for all interactive list rows to guarantee accessibility.
* **FAB Clearance:** Added 88px (`AppSpacing.section + 56`) bottom scroll padding across all scroll views to eliminate FAB overlap.
* **Responsive Architecture:** Centered max-width shell (800–1100px) on tablet and web with side navigation rail, preventing stretched edge-to-edge layouts on wide displays.

---

## 4. Per-Screen Design Decisions

### A. Authentication (Login / Register / Forgot Password)
* Replaced heavy gradient cards with a clean 20px radius card and hairline border.
* Dot-grid background is low-contrast and guarded with `Get.testMode` for test stability.
* Clear on-screen inline validation messages directly beneath inputs instead of transient snackbars.
* Primary buttons are solid terracotta accent; Google sign-in is a hairline-bordered secondary button.

### B. Dashboard
* **Header:** Small date caption (`Sun, 4 Oct`) + time-aware greeting (`Good evening, Anish`) paired with a single Initial Avatar menu button (Theme toggle + Logout), removing cramped icon clutter.
* **Hero Block:** Tonal raised surface featuring a `ProgressRing`, "X of Y done" tabular readout, and active context.
* **Today & Next Up:** Flat list rows with circular checkboxes and 3.5px module indicators; no card-in-card nesting.
* **Module Grid:** 2-column `ModuleTile` grid showing live item counts and soft-tinted icons; eliminated redundant "ACTIVE" badges.

### C. Tasks & Projects
* Segmented horizontal filter row (`All`, `Today`, `Upcoming`, `Completed`) and 8px priority pill filter bar.
* Task cards feature circular toggle checkmarks, priority dots (`HIGH`, `MED`, `LOW`), tabular dates, and swipe actions.
* Create Task Sheet built using `AppBottomSheetFrame` with borderless title, inline chips, and instant confirmation toast.

### D. Calendar & Agenda
* Flat month grid: filled terracotta circle for Today, accent ring for Selected day, and multi-event dot indicators.
* Time-line Day and Week views feature 3.5px event left-bars, tinted backgrounds, and a live 1.5px accent `NowIndicator`.
* View mode switcher uses a compact 8px segmented pill.

### E. Notes, Habits, Finance & Wellness
* Empty states feature crisp, human copy and actionable buttons, eliminating all "once built" or "coming soon" placeholders.
* Finance: Clean Net Balance summary with income/expense metrics, category distribution bars, and budget progress meters.
* Wellness: Daily log tracker with interactive water intake dial, sleep quality slider, workout selector, and mood check-in.

---

## 5. Reusable Component Library (`presentation/widgets/`)
* `AppScaffoldShell`: Responsive desktop navigation rail / mobile scaffold wrapper.
* `SectionLabel`: Uppercase 12px label with `+0.8` tracking in tertiary color.
* `AppListRow`: 48px touch-target list row with hairline dividers and tactile feedback.
* `StatTile`: Metric summary card with module-tinted icon and tabular figure layout.
* `ProgressRing`: Smooth circular progress indicator with percentage center readout.
* `EmptyState` / `AppEmptyView`: Zero-data state with clean icon, explanatory subtitle, and primary action.
* `PrimaryButton` & `SecondaryButton`: Solid terracotta accent button & 1px hairline outlined button.
* `AppChip`: 8px radius segmented filter and tag selector.
* `AppBottomSheetFrame`: 20px radius modal frame with drag handle, title, close icon, and scroll padding.
* `ModuleTile`: High-contrast dashboard tile featuring soft-tinted icon and real metric counts.
