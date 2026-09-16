# Pomly

<p align="center">

![Built for AppSprint 2026](https://img.shields.io/badge/Built%20for-AppSprint%202026-7C3AED?style=for-the-badge)
![Hackathon](https://img.shields.io/badge/Hackathon-AppSprint%202026-blueviolet?style=for-the-badge)

</p>

<p align="center">
  A local-first focus timer, flashcard companion, and study activity tracker.
</p>

---

## Team Information

### Team Name

`[Add team name]`

### Members

| Name | Role |
|---|---|
| `[Add member]` | Developer |
| `[Add member]` | Designer / Developer |
| `[Add member]` | Developer |
| `[Add member]` | Developer |

### Challenge Track

**EduTech**

---

## Problem Statement

Students often manage focused study sessions, revision material, tasks, and progress in separate tools. This makes it difficult to maintain a consistent routine, understand activity over time, and revise material efficiently. Many study tools also depend on a network connection or do not provide a simple workflow for turning notes into revision cards.

## Solution

Pomly combines a configurable Pomodoro timer, local flashcard workflows, and activity tracking in one privacy-friendly application. A student can set focus and rest durations, work through five cycles, import a selectable-text PDF or paste raw notes, review generated cards, manage daily todos, and monitor streaks and goals.

All core data is stored locally on the device. No account or backend is required for the main workflow.

---

## Features

- Configurable focus and regular rest durations.
- Automatic focus/rest cycling.
- Long rest after five completed cycles, calculated as regular rest time multiplied by five.
- Manual restart after the long rest ends.
- Local PDF text extraction.
- Raw text parsing using formats such as:
  - `Q: question` followed by `A: answer`.
  - `term :: definition`.
  - `front -> back`.
  - Definition-style prose and supported study sentences.
- Adjustable flashcard target count.
- Separate local decks for imports.
- Flashcard review with Again, Hard, Good, and Easy ratings.
- Card mastery tracking and flashcard editing.
- Daily todos with completion tracking.
- Consecutive active-day streaks shared between the Focus and Streak screens.
- Rest-day logging with grace-day handling.
- Weekly goals for minutes studied and completed todos.
- Monthly goals derived as weekly goal × 4.
- Yearly goals derived as weekly goal × 12.
- Persistent local settings and study history.
- Editable user display name.

---

## Screenshots

Screenshots should be added before final submission. Current repository assets:

```text
assets/
├── banner.jpeg
└── participant.png
```

| Screen | Preview |
|---|---|
| Focus and Pomodoro timer | `[Add screenshot]` |
| Cards and parser | `[Add screenshot]` |
| Streaks, activity windows, and goals | `[Add screenshot]` |

---

## Demo Video

`[Add public or unlisted demo video URL]`

The demo should be no longer than two minutes and show:

1. The study consistency problem.
2. Pomodoro setup and a focus/rest cycle.
3. Raw text or PDF flashcard import.
4. Flashcard review and editing.
5. Todos, streaks, and weekly goals.

---

## APK Download

`[Add GitHub Releases APK URL]`

The repository currently has a Linux build workflow. The Android APK should be uploaded to a public GitHub Release before submission.

---

## Tech Stack

### Frontend / Mobile Framework

- Flutter
- Dart
- Material 3 widgets
- Provider for reactive application state

### Backend

- None. Pomly is local-first.

### Database / Persistence

- `shared_preferences` for local settings, decks, cards, todos, study days, timer settings, and goals.

### APIs / Services Used

- `file_picker` for selecting local PDF files.
- `syncfusion_flutter_pdf` for local selectable-text PDF extraction.
- A local Dart flashcard parsing engine; no external AI API is required.

---

## Installation

### Prerequisites

- Flutter SDK compatible with Dart `>=3.3.0 <4.0.0`.
- A configured Flutter target such as Android, Linux, Windows, macOS, or a browser-supported target.

### Clone Repository

```bash
git clone https://github.com/nxn0/AppSprint-2026.git
cd AppSprint-2026
```

### Install Dependencies

```bash
flutter pub get
```

### Run the Application

```bash
flutter run
```

### Run Tests

```bash
flutter test
```

### Analyze the Project

```bash
flutter analyze
```

### Build Linux

```bash
flutter build linux
```

The Linux release bundle is generated at:

```text
build/linux/x64/release/bundle/pomly
```

---

## Project Structure

```text
lib/
├── main.dart                         # Application entry point
├── app/
│   └── theme.dart                    # Material theme
├── core/
│   └── constants.dart                # Shared colors and constants
├── data/
│   ├── local_store.dart              # SharedPreferences persistence
│   └── models.dart                   # Cards, decks, todos, and study days
├── features/
│   ├── cards/cards_page.dart         # Decks, parser input, PDF import, review
│   ├── focus/app_state.dart          # Shared state, timer, activity, goals
│   ├── focus/focus_page.dart         # Focus screen and timer controls
│   ├── home/home_screen.dart         # Tab navigation
│   ├── parser/parser.dart            # Parser and PDF extraction boundary
│   └── streak/streak_page.dart       # Todos, streaks, activity, and goals
├── services/
│   └── local_flashcard_engine.dart   # Local flashcard generation and validation
└── services.dart                     # Compatibility exports

test/
└── parser_test.dart                  # Parser and scheduling tests
```

### Architecture

Pomly uses a feature-based Flutter structure with one shared `AppState` provided at the application root. Pages read and update that state through Provider. `AppState` owns timer transitions, activity logging, streak calculation, goal settings, deck operations, and todo operations. `LocalStore` persists state through SharedPreferences. The parser boundary delegates raw text and extracted PDF text to the local flashcard engine, which produces validated `Flashcard` models.

The Focus and Streak pages therefore use the same live activity data. A focus minute or todo event is logged once in `StudyDay`, and both screens derive their displays from that shared record.

---

## Key Highlights

- Local-first study workflow with no required login or network service.
- One shared activity model keeps focus metrics, streaks, todos, and goals synchronized.
- Supports both structured question-answer input and ordinary study prose.
- Adjustable Pomodoro behavior with a mathematically defined five-cycle recovery break.
- Persistent goal tracking for weekly, monthly, and yearly planning.
- Automated parser tests and Flutter static analysis.

---

## Future Improvements

- Add a completed Android APK and store-ready release workflow.
- Add calendar-style historical activity views.
- Add deck rename and bulk card management.
- Add accessibility labels and larger-text layout testing.
- Add export/import for local decks and study history.
- Add widget and integration tests for timer transitions and goal calculations.

---

## Impact

Pomly is designed for students who want a focused, low-friction study routine. It helps users turn existing notes into revision material, maintain a realistic focus rhythm, see whether weekly goals are being met, and keep their study history available without requiring an online account.

The intended impact is better consistency and more useful revision through a single, private, offline-capable study workflow.

---

## AI-Assisted Development Disclosure

AI-assisted development tools were used during implementation, including GitHub Copilot. The project team is responsible for reviewing, testing, understanding, and explaining the submitted code. No external AI API is required at runtime.

---

## Repository Rules and Compliance

This project follows the AppSprint Solution Challenge 2026 repository requirements:

- The repository is intended to remain public.
- Open-source dependencies are used with their package licenses.
- No API keys, passwords, or other secrets are required by the application.
- The project is documented using the provided README template.
- AI-assisted development is disclosed above.
- Team details, screenshots, demo video, APK, and presentation links must be completed before final submission.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).

---

## AppSprint Solution Challenge 2026

Built during **AppSprint Solution Challenge 2026**.

Organized by **App Development IG · muLearn LBSITW**.
