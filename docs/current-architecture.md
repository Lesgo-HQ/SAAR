# Current architecture

## Modules

`lib/` contains Flutter UI, orchestration, flow persistence, matching, synthesis, replay, and safety checks. `android/app/` contains the Flutter Android host and `SaarAccessibilityService`.

## Data flow

Voice input is transcribed by `AsrService`, classified by `LlmClient`, and matched to persisted flows by `FlowMatcher`. `ReplayEngine` creates a `ReplaySession`, grounds each semantic target against the current Accessibility tree, validates the safety boundary, dispatches a native action, and captures a new `ScreenSnapshot` for condition verification.

## Native bridge

`AccessibilityBridge` uses `saar/accessibility` for tree reads, gestures, text entry, service state, and the native sensitive-screen check. `saar/accessibility_events` streams teach-mode traces from Kotlin to Flutter.

## Accessibility service

`SaarAccessibilityService` serializes the active window tree, records teach-mode events, and performs gestures only after its independent fail-closed credential/payment guard passes. A missing service or active window blocks automation.

## Flow schema

A flow has an ID, target app package, trigger intent, examples, typed slots, and ordered `FlowStep`s. Steps use a semantic `target_role`, optional slot/literal value, optional screen precondition/postcondition, and recovery directives. Raw coordinates are not stored in flow data.

## Safety

Flutter and Kotlin independently block password, OTP, PIN, card, bank, UPI, payment, purchase-confirmation, and biometric signals. Replay stops if tree retrieval or native safety validation fails. Safe recovery can dismiss only a small allowlist of harmless popups.

## Current limitations

The local development environment does not expose the Flutter/Dart SDK on `PATH`, so baseline `flutter analyze`, tests, APK builds, device enumeration, and physical-device smoke testing remain unverified. The imported Flutter branch also lacks Gradle wrapper launchers/JAR; regenerate them with the Flutter SDK before building. The current intent/synthesis development provider is configurable, but local SAAR-NLU and production on-device inference are not implemented yet.
