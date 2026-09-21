# SAAR — Smart Automated Action Replay

**Learn any Android task once. Replay it with your voice.**

SAAR is an on-device Android assistant that watches you perform a task once (like ordering groceries), learns the abstract workflow, and replays it whenever you ask — with different items, quantities, or addresses — all via voice command.

Built with Flutter + native Kotlin for a hackathon. 3,200+ lines of production code, zero analysis issues.

---

## Table of Contents

- [How It Works](#how-it-works)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Setup & Installation](#setup--installation)
- [Running the App](#running-the-app)
- [Granting Permissions](#granting-permissions)
- [Testing Your First Flow](#testing-your-first-flow)
- [Architecture](#architecture)
- [Flow JSON Schema](#flow-json-schema)
- [Credential Guard](#credential-guard)
- [Role Ontology](#role-ontology)
- [Configuration](#configuration)
- [Known Limitations](#known-limitations)
- [License](#license)

---

## How It Works

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  1. TEACH    │     │  2. LEARN    │     │  3. REPLAY   │
│              │     │              │     │              │
│ "Teach me to │────▶│ LLM converts │────▶│ "Order milk  │
│  order on    │     │ your taps    │     │  from Zepto"  │
│  Zepto"      │     │ into abstract│     │              │
│              │     │ flow steps   │     │ SAAR replays │
│ You perform  │     │ with roles & │     │ with "milk"  │
│ the task     │     │ param slots  │     │ as the item  │
└──────────────┘     └──────────────┘     └──────────────┘
```

1. **Teach** — Tap the mic, say "teach me to order on Zepto", then switch to Zepto and perform the task normally. SAAR records every tap, type, and scroll via Android's Accessibility Service.

2. **Learn** — When you tap "Stop & Save", the raw action trace is sent to an LLM which abstracts it into a generalised flow with parametrised slots (item name, quantity, address).

3. **Replay** — Next time, say "order 2 kg rice from Zepto". SAAR matches the utterance to the learned flow, fills in the slots, and executes step-by-step — stopping automatically before any payment/credential screen.

---

## Features

| Feature | Status |
|---------|--------|
| Voice-triggered teach & command | ✅ |
| One-shot learning from demonstration | ✅ |
| Abstract flows over element roles (not coordinates) | ✅ |
| Parametrised slots (item, quantity, address) | ✅ |
| Cosine-similarity flow matching + LLM re-rank | ✅ |
| Paraphrase handling ("buy groceries" = "order food") | ✅ |
| **Fail-closed credential guard** (dual Kotlin + Dart) | ✅ |
| Popup/dialog auto-dismiss during replay | ✅ |
| Scroll-to-find target elements | ✅ |
| Ask-when-stuck clarification dialogs | ✅ |
| Noise filtering during teach (system UI, duplicates) | ✅ |
| Manual STOP kill-switch during execution | ✅ |
| Flow library — view, expand, delete saved flows | ✅ |
| Session logging (teach & replay history) | ✅ |
| Configurable LLM endpoint & API key | ✅ |
| Local bag-of-words embedding fallback | ✅ |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI & app logic | Flutter 3.x (Dart), Material 3 |
| State management | Provider (`ChangeNotifier`) |
| Screen automation | Native Kotlin `AccessibilityService` |
| Flutter ↔ Kotlin bridge | `MethodChannel` + `EventChannel` |
| On-device ASR | `speech_to_text` plugin |
| LLM calls | `http` package → Anthropic Messages API |
| Local storage | `sqflite` (flows + session logs) |
| Embeddings | LLM endpoint or local bag-of-words fallback |
| Similarity search | In-memory cosine similarity |

---

## Project Structure

```
SAAR/
├── .env                                          # API keys (never committed)
├── pubspec.yaml                                  # Flutter dependencies
├── README.md                                     # This file
│
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml                   # Permissions + service declaration
│       ├── res/xml/
│       │   └── accessibility_service_config.xml  # Accessibility service config
│       └── kotlin/com/lesgo/saar/
│           ├── SaarAccessibilityService.kt       # UI tree capture, gestures, credential guard
│           └── MainActivity.kt                   # MethodChannel + EventChannel bridge
│
├── lib/
│   ├── main.dart                                 # Entry point, dotenv, Provider
│   ├── app_controller.dart                       # Central state machine
│   │
│   ├── models/
│   │   ├── flow.dart                             # Flow, FlowStep, Slot
│   │   ├── ui_node.dart                          # Accessibility tree node
│   │   ├── action_trace_event.dart               # Teach-session event
│   │   └── role_ontology.dart                    # 15 UI roles + heuristic matcher
│   │
│   ├── services/
│   │   ├── accessibility_bridge.dart             # Typed wrapper over native channels
│   │   ├── asr_service.dart                      # Speech-to-text push-to-talk
│   │   ├── llm_client.dart                       # Anthropic API (classify, synthesize, embed)
│   │   ├── flow_store.dart                       # SQLite CRUD + embedding index
│   │   ├── flow_matcher.dart                     # Cosine similarity + LLM re-rank
│   │   ├── flow_synthesizer.dart                 # Action trace → abstract flow
│   │   ├── replay_engine.dart                    # Step executor with guard + adaptation
│   │   ├── credential_guard.dart                 # Fail-closed sensitive field check
│   │   └── clarification_service.dart            # Ask-when-stuck question builder
│   │
│   └── screens/
│       ├── home_screen.dart                      # Mic button, status, flow list
│       ├── teach_screen.dart                     # Recording indicator, Stop & Save
│       ├── replay_screen.dart                    # Step progress, STOP button, clarification
│       ├── flow_library_screen.dart              # List / expand / delete flows
│       └── settings_screen.dart                  # Accessibility toggle, LLM config
│
└── test/
    └── widget_test.dart
```

**20 source files · 3,200+ lines · 0 analysis issues**

---

## Setup & Installation

### Prerequisites

- **Flutter** 3.13+ with Dart 3.13+
- **Android SDK** (API level 24+ / Android 7.0+)
- **Android device or emulator** with Accessibility support
- **Anthropic API key** (for LLM-powered flow synthesis & matching)

### Step 1 — Clone

```bash
git clone https://github.com/Lesgo-HQ/SAAR.git
cd SAAR
```

### Step 2 — Configure API Key

Create or edit the `.env` file in the project root:

```env
LLM_API_KEY=sk-ant-api03-your-key-here
LLM_ENDPOINT=https://api.anthropic.com/v1/messages
EMBEDDING_ENDPOINT=
```

> **Note:** `EMBEDDING_ENDPOINT` is optional. If left empty, the app falls back to a local 128-dimensional bag-of-words embedding for flow matching. For better paraphrase handling, point it at an embedding API.

> **Security:** The `.env` file is gitignored. Never commit API keys. For CI/CD, use `--dart-define=LLM_API_KEY=xxx` instead.

### Step 3 — Install Dependencies

```bash
flutter pub get
```

### Step 4 — Verify

```bash
flutter analyze
# Should show: "No issues found!"
```

---

## Running the App

### On a physical device (recommended)

```bash
flutter run
```

### Build an APK

```bash
# Debug APK (faster build, larger size)
flutter build apk --debug

# Release APK
flutter build apk --release
```

The APK is output to `build/app/outputs/flutter-apk/app-debug.apk`.

### Using dart-define (no .env file)

```bash
flutter run \
  --dart-define=LLM_API_KEY=sk-ant-your-key \
  --dart-define=LLM_ENDPOINT=https://api.anthropic.com/v1/messages
```

---

## Granting Permissions

### 1. Accessibility Service (required)

This is the core permission that allows SAAR to see and interact with other apps.

1. Launch SAAR → you'll see a **red banner**: *"Accessibility service disabled"*
2. Tap **ENABLE** (or go to **Settings → Accessibility → Installed Services → SAAR**)
3. Toggle **ON** and tap **Allow** on the confirmation dialog
4. Return to SAAR — the banner should disappear and the status shows green

> **Why it's needed:** SAAR uses Android's AccessibilityService API to read UI element trees (what's on screen) and dispatch gestures (taps, swipes, text input) during flow replay. This is the same API used by screen readers like TalkBack.

### 2. Microphone (auto-prompted)

The first time you tap the mic button, Android will prompt for microphone permission. Tap **Allow**.

### 3. Internet (automatic)

Declared in the manifest. No user action needed. Required for LLM API calls.

---

## Testing Your First Flow

### Recommended test app: **Amazon / Flipkart / any shopping app**

#### Phase 1 — Teach a Flow

1. Open SAAR
2. Tap the **mic button** 🎤
3. Say: **"teach me to search on Amazon"**
4. SAAR will show "Recording your actions..." and switch you to teach mode
5. **Switch to Amazon** (use the system task switcher)
6. Perform the task: tap the search bar → type "headphones" → tap search → tap a result
7. **Switch back to SAAR**
8. Tap the red **Stop & Save** button
9. SAAR sends the action trace to the LLM and shows the synthesised flow
10. ✅ Flow is saved! Check it in the **Flow Library** (book icon in top bar)

#### Phase 2 — Replay with Different Parameters

1. Tap the **mic button** 🎤
2. Say: **"search for wireless earbuds on Amazon"**
3. SAAR will:
   - Match your utterance to the learned "search on Amazon" flow
   - Fill "wireless earbuds" into the `item` slot
   - Show step-by-step progress: *"Executing: tap on search_box (Step 1/4)"*
4. Watch it execute automatically!
5. If it encounters a password/OTP/payment screen → **automatically stops** with a message

#### Phase 3 — Test the Credential Guard

1. Navigate to any app's login page (with a password field visible)
2. Try to replay a flow — SAAR will **immediately halt** with:
   > *"HALTED — Sensitive screen detected: password field. Automation stopped for your safety."*

#### Phase 4 — Test Ask-When-Stuck

1. Teach a flow on one app, then try replaying it when that app shows a different screen
2. After 2 retry attempts (popup dismiss + scroll), SAAR will ask:
   > *"I'm stuck at step: tap on search_box. The screen shows: 'Home', 'Profile'. What should I do?"*

---

## Architecture

### State Machine

```
                    ┌─────────┐
                    │  IDLE   │◀──────────────────────┐
                    └────┬────┘                       │
                         │ mic tap                    │
                    ┌────▼────┐                       │
                    │LISTENING│                       │
                    └────┬────┘                       │
                         │ ASR result                 │
                    ┌────▼────────┐                   │
                    │classifyIntent│                  │
                    └──┬───────┬──┘                   │
           "teach"     │       │    "command"         │
              ┌────────▼┐   ┌─▼────────┐             │
              │TEACHING │   │ MATCHING │             │
              └────┬────┘   └────┬─────┘             │
                   │             │                    │
           ┌──────▼──────┐  ┌───▼──────┐             │
           │SYNTHESIZING │  │EXECUTING │             │
           └──────┬──────┘  └───┬──┬───┘             │
                  │             │  │                  │
                  └─────────────┘  │ stuck            │
                                   ▼                  │
                          ┌────────────────┐          │
                          │ CLARIFICATION  │──────────┘
                          └────────────────┘
```

### Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| `AppController` | Central state machine, coordinates all services |
| `AsrService` | Push-to-talk speech recognition via `speech_to_text` |
| `LlmClient` | Three LLM calls: intent classification, flow synthesis, embedding |
| `FlowSynthesizer` | Filters noise from action trace, calls LLM to create abstract flow |
| `FlowStore` | SQLite persistence for flows + in-memory embedding vectors |
| `FlowMatcher` | Cosine similarity search + LLM re-rank for utterance→flow matching |
| `ReplayEngine` | Step-by-step executor with credential guard, adaptation, retries |
| `CredentialGuard` | Dart-side fail-closed check for passwords/OTP/payment fields |
| `ClarificationService` | Builds targeted questions when the system is stuck or ambiguous |
| `AccessibilityBridge` | Typed Dart wrapper over native MethodChannel/EventChannel |
| `SaarAccessibilityService` | Kotlin: UI tree capture, gesture dispatch, native credential guard |
| `RoleOntology` | 15 UI element roles with heuristic `matchScore()` |

### Bridge Protocol

Flutter communicates with the native Kotlin layer via two channels:

**MethodChannel** `saar/accessibility`:
| Method | Args | Returns |
|--------|------|---------|
| `openAccessibilitySettings` | — | `bool` |
| `isServiceEnabled` | — | `bool` |
| `getLastTree` | — | `String?` (JSON) |
| `tap` | `{x, y}` | `bool` |
| `swipe` | `{startX, startY, endX, endY, durationMs}` | `bool` |
| `typeIntoFocused` | `{value}` | `bool` |
| `performActionOnNode` | `{nodeId, actionId}` | `bool` |
| `startTeachSession` | — | `bool` |
| `stopTeachSession` | — | `String` (JSON trace) |
| `isSensitiveScreen` | — | `bool` |

**EventChannel** `saar/accessibility_events`:
- Streams new teach-mode action events every 200ms as JSON arrays

---

## Flow JSON Schema

Every flow learned by SAAR follows this exact schema:

```json
{
  "flow_id": "string (UUID)",
  "app_package": "string (e.g., com.amazon.mShop.android.shopping)",
  "trigger_intent": "string (e.g., search for items on Amazon)",
  "example_utterances": ["search on Amazon", "find something on Amazon"],
  "slots": [
    {
      "name": "item",
      "type": "string",
      "default": null,
      "values": null
    },
    {
      "name": "quantity",
      "type": "int",
      "default": 1,
      "values": null
    }
  ],
  "steps": [
    {
      "id": 1,
      "action": "tap",
      "target_role": "search_box",
      "value_slot": null,
      "value_literal": null
    },
    {
      "id": 2,
      "action": "type",
      "target_role": "search_box",
      "value_slot": "item",
      "value_literal": null
    },
    {
      "id": 3,
      "action": "tap",
      "target_role": "first_search_result",
      "value_slot": null,
      "value_literal": null
    }
  ]
}
```

### Action Types

| Action | Description |
|--------|-------------|
| `tap` | Tap the center of the target element |
| `type` | Focus the element, then set text (from slot or literal) |
| `set_quantity` | Tap a stepper/input and set numeric value |
| `select` | Tap to select from a list |
| `swipe` | Swipe up on a scrollable container |
| `stop_before` | Pause execution and wait for user confirmation |

---

## Credential Guard

The credential guard is the **most critical safety component**. It runs as a **dual-layer, deterministic, fail-closed** check before every single dispatched action.

### What it checks

| Signal | Examples |
|--------|----------|
| `isPassword()` flag | Android's built-in password field detection |
| InputType flags | `TYPE_TEXT_VARIATION_PASSWORD` (0x80), `VISIBLE_PASSWORD` (0x90), `WEB_PASSWORD` (0xE0), `NUMBER_VARIATION_PASSWORD` (0x10) |
| Resource ID patterns | `password`, `passwd`, `otp`, `pin`, `cvv`, `card_number`, `credit_card`, `security_code`, `mpin`, `ssn` |
| Class name patterns | Any class containing `password` |
| Content description | `password`, `otp`, `pin`, `cvv`, `card number`, `security code`, `verification code` |
| Text content | `enter otp`, `enter pin`, `enter cvv`, `enter password`, `verify otp` |
| Hint text | Same patterns as resource ID |

### Fail-closed behaviour

- If the tree is `null` → **BLOCKED**
- If the service is not running → **BLOCKED**
- If the scan throws an exception → **BLOCKED**
- If any node matches any pattern → **BLOCKED**

The guard runs in **both** the Kotlin AccessibilityService (before gesture dispatch) and the Dart ReplayEngine (before calling the bridge). Both must pass for an action to execute.

---

## Role Ontology

SAAR matches UI elements by abstract **roles**, not literal resource IDs or coordinates. The ontology is centralised in `lib/models/role_ontology.dart`:

| Role | Matched by |
|------|-----------|
| `search_box` | EditText + resourceId/desc containing "search" |
| `first_search_result` | First clickable item in a result list |
| `result_card` | Clickable card in search results |
| `add_to_cart_button` | Button with text "add to cart" / "add to bag" |
| `quantity_stepper` | Numeric input / stepper widget |
| `delivery_address` | Address display element |
| `address_selector` | Clickable address chooser |
| `pay_button` | Button with text "pay" / "place order" / "confirm" |
| `payment_screen` | Screen containing payment elements |
| `otp_field` | Input with resourceId containing "otp" / "pin" |
| `password_field` | Input with password InputType flags |
| `login_screen` | Screen containing login elements |
| `popup_dismiss` | Clickable "OK" / "Cancel" / "Close" / "Skip" / "Not now" |
| `cart_icon` | Clickable element with cart/basket in resourceId/desc |
| `checkout_button` | Button with text "checkout" |

Each role has a `matchScore(node, role) → 0.0–1.0` heuristic. The replay engine picks the highest-scoring node above threshold (0.4).

---

## Configuration

### Settings Screen

Access via the **gear icon** in the top-right of the home screen:

- **Accessibility Service** — Status indicator (green/red) + button to open system settings
- **LLM Endpoint** — URL for the Anthropic Messages API (or compatible)
- **API Key** — Your Anthropic API key (stored in memory, not persisted to disk)

### Environment Variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_API_KEY` | — | Anthropic API key |
| `LLM_ENDPOINT` | `https://api.anthropic.com/v1/messages` | Messages API endpoint |
| `EMBEDDING_ENDPOINT` | — | Optional embedding API (falls back to local) |

---

## Known Limitations

1. **Embedding quality** — The local bag-of-words fallback (128-dim hashed tokens) handles simple paraphrases but won't deeply understand semantic similarity. Configure a real embedding endpoint for production use.

2. **Cross-app generalisation** — The role ontology covers e-commerce patterns well (search, cart, checkout). Other categories (messaging, banking, system settings) would need ontology extensions.

3. **Mid-flow clarification resume** — When the replay engine is stuck and asks the user a question, the current implementation treats a failed step as terminal rather than blocking and resuming after the user responds. This is the main stretch goal.

4. **Teach-mode accuracy** — Action recording depends on Android accessibility event timing. Very rapid interactions may be missed or mis-ordered. The noise filter handles common cases (duplicate taps, system UI events).

5. **No overlay UI** — SAAR runs as a standard Activity. A floating overlay for controlling SAAR while in other apps would improve UX. The `SYSTEM_ALERT_WINDOW` permission is declared but not yet used.

6. **Speech locale** — Defaults to device locale. Non-English speech may need explicit locale configuration in the ASR service.

7. **LLM model** — Hardcoded to `claude-3-5-sonnet-20241022`. Should be configurable via the settings screen.

8. **No Android SDK in CI** — Kotlin compilation was not verified in the build environment (no Android SDK), but the code follows standard AccessibilityService patterns and compiles with any standard Android setup.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `provider` | ^6.1.4 | State management |
| `speech_to_text` | ^7.0.0 | On-device speech recognition |
| `sqflite` | ^2.4.2 | Local SQLite database |
| `http` | ^1.3.0 | HTTP client for LLM API |
| `flutter_dotenv` | ^5.2.1 | Environment variable loading |
| `uuid` | ^4.5.1 | Flow ID generation |
| `path_provider` | ^2.1.5 | App directory paths |
| `path` | ^1.9.1 | Path manipulation |
| `permission_handler` | ^11.4.0 | Runtime permission requests |

---

## License

Built for hackathon use. See repository for license details.
