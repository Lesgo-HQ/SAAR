# SAAR

Speech-Aware Adaptive Automation & Replay is an Android accessibility assistant that learns an on-screen task from a spoken instruction and one user demonstration, then replays its abstract plan for later paraphrases and changed parameters.

## Design

```
Speech / typed request
        │
  local semantic parser ──► flow matcher ──► Accessibility replay
        │                        │                    │
Teaching instruction       Room flow store       sensitive-screen guard
        │                        ▲                    │
Accessibility UI events ─► flow synthesizer ────────┘
```

- `automation`: the only component that reads or operates another app. It captures accessible UI events and performs actions using `AccessibilityService` APIs.
- `flow`: turns transient UI nodes into an abstract role plan (`SEARCH_FIELD`, `RESULT_ITEM`, `ADD_TO_CART`, etc.), filters duplicate incidental events, resolves slots, and selects flows by semantic similarity.
- `data`: Room-backed storage for flow definitions and execution reports.
- `voice`: Android `SpeechRecognizer` adapter; typed input remains available when on-device recognition is unavailable.

No tap coordinates, app SDK calls, or hard-coded app flows are persisted. Coordinates may only be used as a last-resort gesture fallback for the currently resolved accessibility node.

## Safety boundary

Before every replay action, the guard scans the live accessibility tree. Password/PIN fields, OTP fields, login controls, and payment signals pause automation and return control to the user. The recorder also never stores credentials: only flow roles and explicitly typed task parameters are saved.

## Running

1. Open in Android Studio (JDK 17, Android SDK API 35) and sync Gradle.
2. Install the `app` variant on an Android 8.0+ device.
3. In **Settings → Accessibility**, enable **SAAR Automation**.
4. Enter or speak a task, tap **Teach this task**, open the target app, and demonstrate the non-sensitive portion. Return to SAAR and tap **Finish teaching**.
5. Enter a paraphrase or changed parameter and tap **Run learned task**.

For reliability, target apps should already be signed in and ready at a stable starting screen. SAAR intentionally pauses rather than operating login, verification, or payment UI.

## Current limitations

- The included semantic reasoner is an offline deterministic fallback. `SemanticReasoner` is the seam for an embedding/LLM provider when network-backed paraphrase quality is required.
- Role inference is intentionally constrained to common commerce/navigation controls. Unusual UI patterns need another teaching pass or a richer semantic provider.
- Standard Android speech recognition availability varies by device/vendor.
- The app launches a learned target via its normal launcher activity when it is not foreground; every in-app operation still goes through accessibility APIs.
