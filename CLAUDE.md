# Mubtaath — Project Rules for Claude Code

These rules are strictly enforced in every AI-assisted session.

## 1. Architecture
Always follow Clean Architecture with three explicit layers:
- **Domain**: entities, use-cases, repository interfaces
- **Data**: repository implementations, data sources, models (DTOs)
- **Presentation**: Cubits, pages, widgets

Never mix layer concerns — no direct API calls inside a Cubit, no business logic inside a widget.

## 2. State Management
State management must use **Cubits (`flutter_bloc`) exclusively**.
- One Cubit per feature/scree0n0.0
0- State classes are immutable; use `copyWith` for updates.
- No `setState()` for non-trivial state. No Provider, Riverpod, or GetX.

## 3. Colors
UI colors must **exclusively use the `AppColors` class** (`lib/core/theme/app_colors.dart`).
- No raw `Color(0xFF...)` values outside `AppColors`.
- No `Colors.*` constants (e.g. `Colors.green`) outside `AppColors`.

## 4. Localization
All user-visible strings must use **`AppLocalizations`** — no hardcoded strings in widgets.
- Access via: `AppLocalizations.of(context)!`
- ARB files live in `lib/core/l10n/`.
- Arabic (`ar`) is the primary locale; English (`en`) is secondary.

## 5. Widget Organization
Standalone sub-widgets must live in **separate files** under the feature's `presentation/widgets/` folder.
- Page files contain only the page scaffold and `BlocBuilder`/`BlocConsumer`.
- Reusable cross-feature widgets live in `lib/core/widgets/`.

## 6. Commands
| Task | Command |
|------|---------|
| Run app | `flutter run` |
| Code analysis | `flutter analyze` |
| Run tests | `flutter test` |
| Code generation | `dart run build_runner build --delete-conflicting-outputs` |
