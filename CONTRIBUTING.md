# Contributing to StickManRunApp

Thank you for your interest in contributing to **StickManRunApp** — a Flutter project that combines a custom stickman running game with a note-taking application.

This document outlines the conventions, workflows, and expectations for contributing. Please read it before opening issues or submitting pull requests.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Code Style & Conventions](#code-style--conventions)
- [Naming Conventions](#naming-conventions)
- [Game-Specific Guidelines](#game-specific-guidelines)
- [Note-Taking App Guidelines](#note-taking-app-guidelines)
- [Commit Message Convention](#commit-message-convention)
- [Branch Naming](#branch-naming)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Lint & Analysis](#lint--analysis)

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
- Dart SDK ^3.11.5 (bundled with Flutter).
- Platform tooling for your target OS (Android Studio / Xcode / VS Code).

### Setup

```bash
# Clone the repository
git clone https://github.com/JPA-Elite/JPANotebookMobileApp.git

# Navigate to the project root
cd StickManRunApp

# Install dependencies
flutter pub get

# Run the app (game mode)
flutter run

# Run tests
flutter test
```

The project has **two sub-systems** living side-by-side:

| Area | Entry Point | Description |
|------|-------------|-------------|
| **Game** | `lib/main.dart` → `StickmanRunApp` | A custom 2D runner game with obstacles, coins, power-ups, and levels |
| **Note-Taking App** | `lib/screens/` (separate) | A local-first note-taking app with rich text, PIN lock, reminders |

---

## Project Structure

```
lib/
├── main.dart                  # App entry point (launches the game)
├── game/                      # Stickman Run game
│   ├── app/
│   │   └── stickman_run_app.dart   # Game MaterialApp + level-select menu
│   ├── engine/
│   │   ├── entities.dart           # Immutable data models (Obstacle, Coin, PowerUp, Stickman, RectF)
│   │   ├── level_config.dart       # Level definitions, tuning parameters, visual themes
│   │   └── stickman_run_engine.dart# Core game loop, physics, collision detection, spawning
│   └── ui/
│       ├── stickman_run_painter.dart   # CustomPaint rendering for the game
│       └── stickman_run_screen.dart    # Game screen (LayoutBuilder, AnimationController, input handling)
├── data/                       # Data repositories (notes, reminders)
├── models/                     # Data models (Note, Reminder)
├── screens/                    # Note-taking app screens
├── services/                   # Platform services (notifications)
├── state/                      # State management (theme, session)
├── utils/                      # Utility functions
└── widgets/                    # Shared UI widgets

test/
└── widget_test.dart            # Widget smoke tests
```

### Directory Purpose

| Directory | Purpose |
|-----------|---------|
| `lib/game/` | Everything related to the stickman runner game engine and UI |
| `lib/game/engine/` | Pure game logic — no Flutter widget/rendering imports beyond `foundation.dart` |
| `lib/game/ui/` | Flutter rendering — `CustomPainter`, screen widgets, input handling |
| `lib/screens/` | Full-screen pages for the note-taking app (create note, settings, reminders, etc.) |
| `lib/models/` | Data classes with `toJson()`/`fromJson()` serialization |
| `lib/services/` | Platform-specific service wrappers (notifications, biometrics, etc.) |
| `lib/state/` | Lightweight state controllers (not a full state management framework) |
| `lib/widgets/` | Reusable widgets shared across note-taking screens (modals, toasts, tab nav) |
| `test/` | Unit tests and widget tests, mirroring `lib/` structure |

---

## Code Style & Conventions

### Dart Effective Style

This project follows the [Dart effective style guide](https://dart.dev/effective-dart/style).

- **Types:** `UpperCamelCase` for classes, enums, typedefs, and extensions.
- **Variables & Methods:** `lowerCamelCase`.
- **Constants:** `lowerCamelCase` with the `const` keyword (not `SCREAMING_CASE`).
- **Private members:** Prefix with `_` (e.g., `_engine`, `_onJump`).
- **File names:** `snake_case.dart`.

### `const` Constructors

Prefer `const` constructors whenever possible. All widget and data classes should have `const` constructors unless they require runtime initialization.

```dart
// Good
const StickmanRunApp({super.key});

// Good
const Obstacle({
  required this.type,
  required this.x,
  ...
});
```

### `@immutable` Annotation

Data classes that represent a snapshot or value object **must** be annotated with `@immutable` from `package:flutter/foundation.dart`.

```dart
import 'package:flutter/foundation.dart';

@immutable
class StickmanRunSnapshot {
  ...
}
```

### Immutability & `copyWith`

All game entity classes and model classes should be **immutable**. Provide a `copyWith` method for creating modified copies.

```dart
@immutable
class Stickman {
  final double x;
  final double y;
  final double vy;

  const Stickman({required this.x, required this.y, required this.vy});

  Stickman copyWith({double? y, double? vy}) {
    return Stickman(
      x: x,
      y: y ?? this.y,
      vy: vy ?? this.vy,
    );
  }
}
```

### Avoid `print()`

Use `debugPrint()` for temporary debugging output. Remove or comment out `print()` and `debugPrint()` calls before committing. Prefer structured logging if the project adds a logging service later.

### Imports Ordering

Group imports in this order, separated by a blank line:

1. Dart SDK imports (`dart:math`, `dart:convert`)
2. Flutter imports (`package:flutter/...`)
3. Project imports (relative or `package:flutter_app/...`)

```dart
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'entities.dart';
import 'level_config.dart';
```
---

## Naming Conventions

| Category | Convention | Example |
|----------|-----------|---------|
| **Files** | `snake_case.dart` | `stickman_run_engine.dart`, `level_config.dart` |
| **Classes** | `UpperCamelCase` | `StickmanRunEngine`, `NoteAttachment`, `RectF` |
| **Enums** | `UpperCamelCase` | `GameStatus`, `ObstacleType`, `PowerUpType` |
| **Enum values** | `lowerCamelCase` | `GameStatus.ready`, `ObstacleType.rollingRock` |
| **Methods/Functions** | `lowerCamelCase` | `collisionRect()`, `_spawnPowerUpNearColumn()` |
| **Variables** | `lowerCamelCase` | `_groundY`, `_spawnTimerSec`, `_coinsCollected` |
| **Constants** | `lowerCamelCase` (prefixed `k` optional) | `_smashDurationSec`, `_smashCooldownTimeSec` |
| **Private (file/class level)** | Prefix with `_` | `class _StickmanRunAppState`, `void _tick()` |
| **Widget files** | Match the widget class name in snake_case | `stickman_run_screen.dart` → `StickmanRunScreen` |

---

## Game-Specific Guidelines

The game in `lib/game/` is a **custom 2D engine** built without external game frameworks. Please follow these patterns:

### 1. Engine / UI Separation

- **`lib/game/engine/`** — Pure logic only. No imports from `package:flutter/material.dart`. Use only `package:flutter/foundation.dart` when needed (e.g., `@immutable`).
- **`lib/game/ui/`** — Flutter rendering and input. Uses `CustomPainter`, `AnimationController`, `LayoutBuilder`, and widgets.

Do **not** import engine classes into UI classes in a way that couples them. Use the snapshot pattern (`StickmanRunSnapshot`) to pass state from engine to painter.

### 2. Entity Classes

All entity classes must be:
- `@immutable`
- Have `const` constructors
- Have a `collisionRect()` method returning `RectF`
- Have a `copyWith()` method for positional updates

```dart
@immutable
class Coin {
  final double x;
  final double y;
  final double radius;
  final double phase;

  const Coin({required this.x, required this.y, required this.radius, required this.phase});

  RectF collisionRect() { ... }
  Coin copyWith({double? x, double? y, double? phase}) { ... }
}
```

### 3. Level Configuration

Levels are defined in `level_config.dart` via the `LevelConfig` class. Each level specifies:
- `tuning` — Physics constants (gravity, jump velocity, speed)
- `visuals` — Color themes, background details
- `spawnRules` — Obstacle types, power-up availability, difficulty curve

Add new levels by extending `LevelConfig.all()`.

### 4. Custom Painting

- Game rendering uses `CustomPainter` subclasses (e.g., `StickmanRunPainter`).
---

## Note-Taking App Guidelines

The note-taking app (`lib/screens/`, `lib/models/`, `lib/data/`, etc.) follows standard Flutter conventions:

### 1. Screen Widgets

- Each screen is a `StatefulWidget` with a private `_ScreenNameState`.
- Use `const` constructors for screen widgets.
- Accept required parameters (e.g., note ID) explicitly.

```dart
class NoteDetailScreen extends StatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}
```

### 2. Models

- Data models have `toJson()` and `factory FromJson()` methods for serialization.
- Use `DateTime` objects for timestamps; serialize via `toIso8601String()`.
- Models are immutable or effectively immutable.

### 3. Repositories

Data access is abstracted through repository classes in `lib/data/`. Repositories handle:
- Reading/writing from local storage
- JSON serialization/deserialization
- Error handling

### 4. State Management

State is managed via lightweight **controller classes** in `lib/state/`. Currently used:
- `ThemeController` — Theme brightness and preferences
- `UnlockedNotesSession` — Tracks which locked notes have been unlocked in the current session

Controllers extend `ChangeNotifier` or use a simple listener pattern.

### 5. Reusable Widgets

Shared widgets live in `lib/widgets/`. These include:
- `ConfirmModal` — Confirmation dialog
- `PinLockModal` — PIN entry modal for locked notes
- `ScheduleDeleteModal` — Scheduling note deletion
- `TabNavigation` — Bottom tab bar
- `TopToast` — In-app toast notifications

---

## Commit Message Convention
We use [Conventional Commits](https://www.conventionalcommits.org/)-style messages:

```
<type>: <short description>
```

### Types

| Type | When to use |
|------|------------|
| `feat` | A new feature (game mechanic, screen, service) |
| `fix` | A bug fix |
| `refactor` | Code restructuring without behavior change |
| `chore` | Build/config changes, dependency updates, tooling |
| `docs` | Documentation only (including this file) |
| `test` | Adding or modifying tests |
| `style` | Formatting, linting, code style (no logic change) |

### Examples from this project

```
feat: Add smash mechanic with cooldown and visual effects in the game
fix: Adjust stickman starting position for better alignment and padding
refactor: Remove unused _BottomLegend and _LegendRound widgets
feat: Add random variation to obstacle spawn distances for improved gameplay dynamics
```

### Rules

- Use the **imperative present tense** ("Add" not "Added" / "Adds").
- Keep the subject line **under 72 characters**.
- Do **not** end the subject line with a period.
- Use lowercase for the subject line.
- Add a blank line and a longer body for complex changes.
---

## Branch Naming

| Prefix | Example |
|--------|---------|
| `feature/<description>` | `feature/coin-magnet-powerup` |
| `fix/<description>` | `fix/respawn-collision-timing` |
| `refactor/<description>` | `refactor/engine-snapshot-pattern` |
| `chore/<description>` | `chore/update-flutter-version` |
| `docs/<description>` | `docs/contributing-guide` |

Use `kebab-case` for the description. Keep branch names descriptive but concise.

---

## Testing Guidelines

### Running Tests

```bash
# Run all tests
flutter test

# Run a specific test file
flutter test test/widget_test.dart
```

### Test Structure

- Place tests in the `test/` directory, mirroring the `lib/` structure.
- Name test files with `_test.dart` suffix.
- Use `package:flutter_app/...` imports to reference app code.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/game/app/stickman_run_app.dart';
```

### What to Test

| Area | Test Type | What to Cover |
|------|-----------|---------------|
| **Game Engine** | Unit tests (`test/game/engine/`) | Collision detection (`RectF.intersects`), level configuration, score calculation, power-up activation, game status transitions |
| **Game UI** | Widget tests (`test/game/ui/`) | Smoke tests for screens, button rendering, painter output |
| **Data Models** | Unit tests | JSON serialization round-trips, computed properties |
| **Screens** | Widget tests | Navigation, form interactions, state display |
| **Widgets** | Widget tests | Rendering, tap handlers, accessibility |

### Naming Convention for Tests

Use descriptive test names with `test()` or `testWidgets()`:

```dart
test('RectF.intersects returns true when rectangles overlap', () { ... });
testWidgets('StickmanRunApp renders PLAY button', (tester) async { ... });
```

---

## Pull Request Process

1. **Create a branch** from `main` following the [branch naming convention](#branch-naming).
2. **Make your changes** following the conventions in this guide.
3. **Run `flutter analyze`** and ensure zero warnings/errors.
4. **Run `flutter test`** and ensure all tests pass.
5. **Write or update tests** to cover your changes.
6. **Create a pull request** on GitHub targeting the `main` branch.
7. **Fill out the PR description** with:
   - What the change does
   - Why it's needed
   - How it was tested
   - Screenshots/GIFs for visual changes (game UI, new screens)
8. **Request review** from at least one contributor.
9. **Address review feedback** — keep the commit history clean (you may push additional commits or amend).
10. **Merge** once approved. Squash commits when merging to keep `main` history clean.

### PR Checklist

Before submitting, ensure:

- [ ] Code follows project style and conventions
- [ ] `flutter analyze` passes with no warnings
- [ ] New tests are added for changed behavior
- [ ] All existing tests pass (`flutter test`)
- [ ] Documentation is updated if needed (README, inline docs)
- [ ] Commit messages follow the convention
- [ ] Branch is up to date with `main`

---

## Issue Reporting

When opening an issue on GitHub, please include:

### Bug Reports

- **Description** — Clear summary of the bug.
- **Steps to reproduce** — Minimal, complete steps.
- **Expected behavior** — What should happen.
- **Actual behavior** — What actually happens.
- **Environment** — Device/emulator, OS version, Flutter version (`flutter --version`).
- **Screenshots/Recordings** — Helpful for game rendering or UI issues.
- **Logs** — Any relevant error output from the console.

### Feature Requests

- **Problem statement** — What need does this address?
- **Proposed solution** — How you envision the feature working.
- **Alternative approaches** — Any other solutions considered.
- **Relevant area** — Game engine, game UI, note-taking app, etc.

---

## Lint & Analysis

Run the Dart analyzer before committing:

```bash
flutter analyze
```

The project uses `flutter_lints ^6.0.0` with the recommended Flutter lint set (`package:flutter_lints/flutter.yaml`).

### Current Analyzer Exclusions

The `analysis_options.yaml` currently excludes all `lib/` subdirectories from analysis. This is a known issue. When contributing:

1. **Do not add new analyzer warnings** even though the analyzer may not catch them in excluded directories.
2. Follow the conventions in this guide to keep code clean.
3. Consider contributing toward removing exclusions and enabling more lint rules as a separate effort.

### Additional Dart Conventions

- Avoid `dynamic` types — use proper type annotations.
- Prefer `final` over `var` for local variables that are never reassigned.
- Use collection literals (`[]`, `{}`) over constructors (`List()`, `Map()`).
- Use `??` and `?.` operators over explicit null checks where appropriate.

---

## Questions?

If you have questions about contributing, open a [Discussion](https://github.com/JPA-Elite/JPANotebookMobileApp/discussions) on GitHub or reach out through the repository's issue tracker.

