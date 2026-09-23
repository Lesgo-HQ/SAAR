# SAAR --- PLAN.md

## Samsung PRISM Theme 3: Implementation & Submission Master Plan

> **Purpose:** This file is the single source of truth for a coding
> agent working on the SAAR repository.
>
> **Primary objective:** Convert `revamp/flutter` into the new `main`
> baseline and evolve it into a robust, safety-bounded, semantically
> grounded Android workflow-learning/replay system that can satisfy the
> Samsung PRISM Theme 3 evaluation scenarios.
>
> **Important:** Do not rewrite the project blindly. Inspect the
> existing implementation first, preserve working functionality,
> implement the plan incrementally, run tests/builds after each phase,
> and never claim a task is complete without verification.

------------------------------------------------------------------------

# 0. Non-Negotiable Engineering Rules

The coding agent MUST follow these rules throughout the implementation.

## 0.1 Architecture

Use:

``` text
Flutter UI / orchestration
        |
        v
SAAR Intelligence
        |
        v
Flow retrieval / slot resolution
        |
        v
ReplaySession
        |
        v
Screen-state analysis
        |
        v
Semantic node grounding
        |
        v
Safety validation
        |
        v
Native Kotlin AccessibilityService
```

The LLM/model MUST NOT directly control Android.

The AI may propose:

``` json
{
  "action": "tap",
  "role": "ADD_TO_CART",
  "confidence": 0.94
}
```

Deterministic code must then:

1.  inspect the current Accessibility tree
2.  find a matching semantic node
3.  validate safety
4.  validate preconditions
5.  execute through AccessibilityService
6.  verify the postcondition

Never allow a model response to directly become an arbitrary tap,
coordinate, text input, or system action.

------------------------------------------------------------------------

# 1. Repository Baseline

Repository:

``` text
https://github.com/Lesgo-HQ/SAAR
```

Primary branch to become the new baseline:

``` text
revamp/flutter
```

Old `main` is the earlier native Android/Kotlin prototype.

`revamp/flutter` contains the newer Flutter + Kotlin hybrid
architecture.

The final project MUST have one coherent application architecture.

Do not retain two competing Android application modules.

The final Android application should use:

``` text
android/app/
```

and the Flutter application root.

The old native-only:

``` text
app/
```

module should not remain as a second competing application module.

------------------------------------------------------------------------

# 2. Migration: revamp/flutter → main

## Goal

Make the `revamp/flutter` architecture the new `main`.

## Safe procedure

Before modifying anything:

``` bash
git checkout main
git pull origin main
git branch backup/main-before-flutter-migration
```

Fetch:

``` bash
git fetch origin
```

Inspect:

``` bash
git log --oneline --decorate --all --graph -20
git diff main..origin/revamp/flutter
```

Then merge:

``` bash
git merge origin/revamp/flutter --allow-unrelated-histories
```

Resolve conflicts by treating the Flutter branch as the intended
application architecture.

Do not blindly preserve the old `app/` Android module.

After resolving:

``` bash
git add .
git commit -m "Merge Flutter architecture into main"
git push origin main
```

If GitHub permissions do not allow a remote PR/merge, perform the merge
locally and push from a properly authenticated developer environment.

## Migration acceptance criteria

-   [ ] `main` contains Flutter application
-   [ ] `main` contains `android/app`
-   [ ] old competing `app/` module removed
-   [ ] project opens in Android Studio
-   [ ] `flutter pub get` succeeds
-   [ ] `flutter analyze` succeeds
-   [ ] debug APK builds
-   [ ] release APK builds
-   [ ] application launches on a physical Android device
-   [ ] AccessibilityService can be enabled
-   [ ] teach mode works
-   [ ] replay mode works

------------------------------------------------------------------------

# 3. Existing Architecture to Preserve

The existing `revamp/flutter` implementation already contains important
functionality.

Preserve and improve:

``` text
lib/
├── app_controller.dart
├── main.dart
├── models/
│   ├── action_trace_event.dart
│   ├── flow.dart
│   ├── role_ontology.dart
│   └── ui_node.dart
├── services/
│   ├── accessibility_bridge.dart
│   ├── asr_service.dart
│   ├── clarification_service.dart
│   ├── credential_guard.dart
│   ├── flow_matcher.dart
│   ├── flow_store.dart
│   ├── flow_synthesizer.dart
│   ├── llm_client.dart
│   └── replay_engine.dart
└── screens/
    ├── flow_library_screen.dart
    ├── home_screen.dart
    ├── replay_screen.dart
    ├── settings_screen.dart
    └── teach_screen.dart

android/app/src/main/kotlin/com/lesgo/saar/
├── MainActivity.kt
└── SaarAccessibilityService.kt
```

Do not remove working safety functionality during refactoring.

------------------------------------------------------------------------

# 4. Target Architecture

The final target architecture is:

``` text
                              USER
                               |
                    voice / text command
                               |
                               v
                    +-------------------+
                    | Flutter UI        |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Intent Parser     |
                    | Slot Extractor    |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Flow Matcher      |
                    | Embedding Search  |
                    | Confidence Gate   |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | ReplaySession     |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | ScreenSnapshot    |
                    | State Analyzer    |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Semantic Grounder |
                    | Role Ontology     |
                    | Node Ranking      |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Safety Gate       |
                    | Credential Guard  |
                    | Payment Guard     |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Recovery Engine   |
                    +---------+---------+
                              |
                              v
                    +-------------------+
                    | Kotlin            |
                    | AccessibilitySvc  |
                    +---------+---------+
                              |
                              v
                       Android target app
```

------------------------------------------------------------------------

# 5. Phase 0 --- Baseline Build and Audit

Before implementing features, establish a clean baseline.

## Tasks

Run:

``` bash
flutter doctor
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run
```

Build:

``` bash
flutter build apk --debug
flutter build apk --release
```

Inspect:

``` text
pubspec.yaml
android/app/build.gradle.kts
android/settings.gradle.kts
android/gradle.properties
AndroidManifest.xml
accessibility_service_config.xml
```

Inspect every existing service before rewriting it.

Create:

``` text
docs/current-architecture.md
```

containing:

-   current modules
-   data flow
-   native bridge
-   AccessibilityService behavior
-   current flow schema
-   current safety implementation
-   current limitations

## Acceptance criteria

-   [ ] baseline build documented
-   [ ] baseline tests documented
-   [ ] no unexplained build warnings
-   [ ] physical-device smoke test completed

------------------------------------------------------------------------

# 6. Phase 1 --- Security and Configuration Cleanup

The final application must not depend on a committed API key.

Create:

``` text
.env.example
```

Example:

``` env
LLM_PROVIDER=anthropic
LLM_ENDPOINT=
LLM_MODEL=
LLM_API_KEY=
EMBEDDING_ENDPOINT=
```

Ensure:

``` text
.env
```

is ignored.

Never commit a real API key.

Do not hard-code:

``` text
Claude model names
API keys
private endpoints
```

The code should load provider configuration dynamically.

## Important model strategy

Claude is now the development/API model.

However, Claude must NOT be the required core runtime model in the final
architecture.

Claude can be used for:

-   development
-   dataset generation
-   teacher labeling
-   flow synthesis during development
-   error analysis
-   model distillation

The final SAAR intelligence path should be capable of running locally.

------------------------------------------------------------------------

# 7. Phase 2 --- ReplaySession

This is the highest-priority functional fix.

The current replay flow can enter a waiting/clarification state but does
not maintain a durable execution session that cleanly resumes the exact
failed step.

Implement:

``` dart
class ReplaySession {
  final String runId;
  final Flow flow;
  final Map<String, dynamic> slots;

  int currentStep;
  ReplayStatus status;

  int recoveryAttempts;

  ScreenSnapshot? lastScreen;

  ReplaySession({
    required this.runId,
    required this.flow,
    required this.slots,
    this.currentStep = 0,
    this.status = ReplayStatus.executing,
    this.recoveryAttempts = 0,
    this.lastScreen,
  });
}
```

Required operations:

``` text
start()
pause()
resume()
stop()
haltForSafety()
fail()
complete()
```

State machine:

``` text
IDLE
 |
 v
EXECUTING
 |
 +----> RECOVERING
 |          |
 |          +----> EXECUTING
 |
 +----> WAITING_FOR_USER
 |             |
 |             v
 |         RESUME SAME STEP
 |
 +----> HALTED_SENSITIVE
 |
 +----> CANCELLED
 |
 v
COMPLETED
```

## Critical behavior

If step 4 fails:

``` text
step 4
  ↓
stuck
  ↓
ask user
  ↓
user responds
  ↓
re-read current UI
  ↓
resume step 4
  ↓
step 5
```

Never restart at step 1.

------------------------------------------------------------------------

# 8. Phase 3 --- ScreenSnapshot

Create:

``` text
lib/models/screen_snapshot.dart
```

Recommended model:

``` dart
class ScreenSnapshot {
  final String packageName;
  final Set<String> roles;
  final List<String> visibleTexts;
  final String stateHash;
  final DateTime capturedAt;

  const ScreenSnapshot({
    required this.packageName,
    required this.roles,
    required this.visibleTexts,
    required this.stateHash,
    required this.capturedAt,
  });
}
```

Generate a normalized state hash from meaningful UI information.

Do NOT use raw coordinates as state identity.

Include:

-   package
-   semantic roles
-   normalized visible text
-   important node attributes
-   screen-level structural information

Ignore unstable data such as:

-   timestamps
-   random IDs
-   transient coordinates

------------------------------------------------------------------------

# 9. Phase 4 --- Screen Preconditions and Postconditions

Extend flow steps.

Target format:

``` json
{
  "id": 4,
  "action": "tap",
  "target_role": "ADD_TO_CART",
  "precondition": {
    "required_roles": ["PRODUCT_DETAIL"],
    "forbidden_roles": ["PASSWORD", "OTP", "PAYMENT"]
  },
  "postcondition": {
    "required_roles": ["CART"]
  },
  "recovery": [
    "dismiss_popup",
    "refind_node",
    "scroll"
  ]
}
```

Before execution:

``` text
current state
    ↓
precondition validation
    ↓
semantic target lookup
```

After execution:

``` text
action
    ↓
wait for UI update
    ↓
new snapshot
    ↓
postcondition validation
```

An Android gesture returning `true` is NOT sufficient evidence that the
workflow step succeeded.

------------------------------------------------------------------------

# 10. Phase 5 --- RecoveryEngine

Create:

``` text
lib/services/recovery_engine.dart
```

Move recovery logic out of `ReplayEngine`.

Recovery strategy order:

``` text
1. refresh Accessibility tree
2. re-evaluate current screen
3. detect blocking popup
4. dismiss safe popup
5. re-rank semantic nodes
6. detect off-screen target
7. scroll
8. refresh tree
9. re-rank target
10. check app/package transition
11. check state mismatch
12. ask user
```

Never perform arbitrary destructive actions during recovery.

Safe popup dismissal candidates:

``` text
OK
Close
Dismiss
Not now
Skip
Later
No thanks
Got it
```

Do not automatically dismiss:

``` text
Confirm purchase
Pay
Place order
Delete
Remove account
Transfer
Send money
```

These must be treated as high-risk.

------------------------------------------------------------------------

# 11. Phase 6 --- Role Ontology

Replace the limited role set with a more comprehensive semantic
ontology.

Minimum roles:

``` text
SEARCH_FIELD
SEARCH_SUBMIT

RESULT_LIST
RESULT_ITEM

PRODUCT_CARD
PRODUCT_DETAIL

PRIMARY_ACTION
ADD_TO_CART

CART
CHECKOUT

QUANTITY_INCREASE
QUANTITY_DECREASE
QUANTITY_VALUE
QUANTITY_STEPPER

ADDRESS_SELECTOR
ADDRESS_OPTION

FILTER
SORT

NAVIGATION
BACK
DISMISS
CONFIRM

LOGIN
PASSWORD
OTP

PAYMENT
PAY
PLACE_ORDER
```

Roles must be app-independent.

Do not define:

``` text
AMAZON_SEARCH_BUTTON
ZEPTO_SEARCH_BUTTON
FLIPKART_SEARCH_BUTTON
```

Define:

``` text
SEARCH_SUBMIT
```

and map the current Accessibility tree to it.

------------------------------------------------------------------------

# 12. Phase 7 --- Semantic Node Ranking

Implement a dedicated:

``` text
NodeRanker
```

The score should combine:

``` text
role compatibility
text similarity
content-description similarity
class compatibility
clickability
editability
structural context
screen context
historical consistency
```

Do not rely only on resource IDs.

Resource IDs may be useful evidence but must not be the identity of a
workflow step.

Suggested initial confidence policy:

``` text
>= 0.85
    execute

0.65 - 0.85
    require additional verification

< 0.65
    clarify / recover
```

These are starting values and must be tuned using real test data.

------------------------------------------------------------------------

# 13. Phase 8 --- ParsedIntent

Create:

``` text
lib/models/parsed_intent.dart
```

``` dart
class ParsedIntent {
  final String intent;
  final String? app;
  final Map<String, dynamic> slots;
  final double confidence;

  const ParsedIntent({
    required this.intent,
    this.app,
    required this.slots,
    required this.confidence,
  });
}
```

Examples:

Input:

``` text
Order 2 kg rice from Zepto
```

Expected:

``` json
{
  "intent": "order_item",
  "app": "zepto",
  "slots": {
    "item": "rice",
    "quantity": 2
  }
}
```

Input:

``` text
Get it delivered to my office
```

Expected:

``` json
{
  "intent": "select_address",
  "slots": {
    "address": "office"
  }
}
```

------------------------------------------------------------------------

# 14. Phase 9 --- Slot Extraction

Support at minimum:

``` text
item
quantity
address
```

Potential future slots:

``` text
category
brand
color
size
sort
filter
location
```

Use typed slot values.

Example:

``` json
{
  "quantity": {
    "type": "integer",
    "value": 3
  }
}
```

Normalize:

``` text
two
2
two units
2 units
x2
```

into:

``` text
2
```

Do not allow malformed values to reach execution.

------------------------------------------------------------------------

# 15. Phase 10 --- FlowMatcher Redesign

The current matcher uses embeddings and an LLM reranker.

Improve it to:

``` text
query
  ↓
intent parse
  ↓
embedding
  ↓
top-K retrieval
  ↓
intent compatibility
  ↓
slot compatibility
  ↓
app compatibility
  ↓
confidence + margin
  ↓
execute / verify / clarify
```

Do not use the fragile current strategy of checking whether an LLM
response happens to contain a candidate flow's trigger text.

The matcher should return structured data:

``` json
{
  "selected_flow_id": "uuid",
  "confidence": 0.91,
  "slots": {
    "item": "rice",
    "quantity": 2
  }
}
```

If using a model during development, require strict JSON/schema
validation.

------------------------------------------------------------------------

# 16. Phase 11 --- Ambiguity Detection

Calculate:

``` text
best_score
second_best_score
margin
```

Example:

``` text
Flow A = 0.81
Flow B = 0.79
margin = 0.02
```

This is ambiguous.

Ask a clarification question.

Example:

``` text
I found two possible workflows:
1. Search for an item
2. Add an item to the cart

Which one do you want?
```

Do not silently select a workflow when confidence is insufficient.

------------------------------------------------------------------------

# 17. Phase 12 --- Unknown Intent

Create an explicit:

``` text
UNKNOWN
```

intent.

If no learned workflow is appropriate:

``` text
I don't have a learned workflow for that task.
Would you like to teach me?
```

Never map an unknown command to the closest unrelated workflow.

------------------------------------------------------------------------

# 18. Phase 13 --- Credential Guard

Preserve the existing dual guard:

``` text
Flutter CredentialGuard
+
Kotlin CredentialGuard
```

Both must fail closed.

Expand detection to include:

``` text
password
passwd
OTP
verification code
PIN
MPIN
CVV
CVC
security code
card number
credit card
debit card
bank account
UPI
IFSC
payment
pay now
place order
confirm purchase
biometric confirmation
```

Detection signals:

``` text
input type
password flags
resource ID
class name
content description
text
hint text
semantic role
screen context
```

Critical rule:

``` text
If tree == null
    BLOCK

If safety check throws
    BLOCK

If service unavailable
    BLOCK

If sensitive state detected
    BLOCK
```

------------------------------------------------------------------------

# 19. Phase 14 --- Payment Boundary

The system must stop before:

``` text
payment
OTP
password
PIN
CVV
banking credentials
final purchase confirmation
```

For example:

``` text
Checkout
   ↓
Payment detected
   ↓
STOP
```

UI message:

``` text
SAAR stopped for safety.

The workflow reached a payment or credential step.
SAAR will not enter credentials or complete the transaction.
```

Never let the AI override this.

------------------------------------------------------------------------

# 20. Phase 15 --- Logging and Privacy

Create:

``` text
lib/models/execution_report.dart
lib/services/execution_reporter.dart
```

Report:

``` json
{
  "run_id": "uuid",
  "flow_id": "uuid",
  "status": "completed",
  "current_step": 8,
  "total_steps": 8,
  "recoveries": 1,
  "clarifications": 0,
  "stopped_reason": null
}
```

Allowed logs:

``` text
flow ID
step ID
semantic role
package name
confidence
recovery action
status
timestamps
```

Never persist:

``` text
password
OTP
PIN
CVV
card number
authentication secrets
```

Redact sensitive text.

------------------------------------------------------------------------

# 21. Phase 16 --- Teach Mode Improvements

The AccessibilityService should record meaningful actions:

``` text
tap
type
scroll
select
focus
screen transition
```

But raw traces must be filtered.

Remove:

``` text
duplicate focus
system UI
notification shade
keyboard-only noise
duplicate taps
irrelevant navigation
transient events
```

Keep:

``` text
meaningful state-changing actions
```

Every important action should capture:

``` text
before screen
action
after screen
```

This enables better flow synthesis.

------------------------------------------------------------------------

# 22. Phase 17 --- Flow Synthesis

Current flow synthesis can use an LLM during development.

However, synthesis output must be schema-validated.

Expected output:

``` json
{
  "flow_id": "uuid",
  "domain": "food_ordering",
  "intent": {
    "name": "order_item"
  },
  "slots": [],
  "steps": []
}
```

Reject malformed model output.

Validate:

-   valid action
-   valid semantic role
-   valid slot references
-   valid step ordering
-   no credential actions
-   no payment actions
-   no raw coordinate dependencies

------------------------------------------------------------------------

# 23. Phase 18 --- Build Our Own SAAR Intelligence Model

## Objective

The final project should not require Claude for core intent
understanding.

Do NOT attempt to train a general-purpose LLM from scratch.

Build a small task-specific model:

``` text
SAAR-NLU
```

with:

``` text
shared encoder
   |
   +-- intent classification head
   |
   +-- slot tagging head
   |
   +-- sentence embedding head
```

Architecture:

``` text
text
 ↓
small Transformer encoder
 ↓
 ├── intent classifier
 ├── BIO slot tagger
 └── embedding vector
```

Target deployment:

``` text
ONNX
+
quantization
+
Android
```

The model should be small enough for practical on-device inference.

------------------------------------------------------------------------

# 24. SAAR-NLU Dataset

Create:

``` text
ml/
├── dataset/
├── training/
├── evaluation/
├── export/
└── models/
```

Dataset must contain:

``` text
intent
text
slots
app
difficulty
source
```

Example:

``` json
{
  "text": "Order two packets of rice",
  "intent": "order_item",
  "slots": {
    "item": "rice",
    "quantity": 2
  }
}
```

Initial target:

``` text
5,000–20,000 validated utterances
```

Do not fabricate benchmark results. Report only measured metrics.

------------------------------------------------------------------------

# 25. Claude as Teacher

Claude may be used to generate development data.

For every intent, generate:

-   exact commands
-   paraphrases
-   short commands
-   verbose commands
-   incomplete commands
-   noisy commands
-   ambiguous commands
-   hard negatives
-   unknown commands

Example:

``` text
Intent:
order_item

Generate:
- 100 normal examples
- 100 paraphrases
- 50 ambiguous examples
- 50 hard negatives
```

Then:

``` text
Claude-generated
      ↓
automatic validation
      ↓
human review
      ↓
training dataset
```

Do not treat synthetic data as automatically correct.

------------------------------------------------------------------------

# 26. Slot Tagging

Use BIO-style labels.

Example:

``` text
Order two kg basmati rice

Order       O
two         B-QUANTITY
kg          I-QUANTITY
basmati     B-ITEM
rice        I-ITEM
```

For:

``` text
Deliver it to my office
```

use:

``` text
office      B-ADDRESS
```

------------------------------------------------------------------------

# 27. Hard Negatives

Train similar intents against each other.

Examples:

``` text
search for milk
order milk
add milk to cart
change milk quantity
checkout milk
```

Also:

``` text
buy milk
buy milk tomorrow
buy two milk packets
buy milk for my office
```

This is essential for robust ambiguity detection.

------------------------------------------------------------------------

# 28. Unknown Intent Dataset

Include commands unrelated to learned workflows:

``` text
tell me a joke
what is the weather
open camera
play music
send a message
book a flight
```

Expected:

``` text
UNKNOWN
```

The system must not execute an unrelated learned workflow.

------------------------------------------------------------------------

# 29. Model Training

Recommended training pipeline:

``` text
dataset
 ↓
train/validation/test split
 ↓
tokenization
 ↓
multi-task training
 ↓
intent loss
+
slot loss
+
contrastive embedding loss
 ↓
evaluation
 ↓
export
```

Use appropriate metrics:

``` text
Intent:
accuracy
macro F1

Slots:
precision
recall
F1
exact match

Embeddings:
Recall@1
Recall@3
MRR

Unknown:
precision
recall

Safety:
false execution rate
```

Keep the test set completely separate from training data.

------------------------------------------------------------------------

# 30. Model Export

Export:

``` text
PyTorch
   ↓
ONNX
   ↓
quantization
   ↓
Android runtime
```

Target:

``` text
SAAR-NLU.onnx
```

Store versioned models:

``` text
ml/models/
```

Example metadata:

``` json
{
  "model": "SAAR-NLU",
  "version": "0.1.0",
  "dataset_version": "0.1",
  "embedding_dimension": 384
}
```

Only record real measured size/latency/accuracy.

------------------------------------------------------------------------

# 31. Runtime Model Integration

Create an abstraction:

``` dart
abstract class IntentModel {
  Future<ParsedIntent> parse(String text);
  Future<List<double>> embed(String text);
}
```

Implement:

``` text
LocalIntentModel
```

and optionally:

``` text
DevelopmentClaudeModel
```

Production default:

``` text
LocalIntentModel
```

Claude must not be required for ordinary replay.

------------------------------------------------------------------------

# 32. Model Fallback

If local inference fails:

``` text
do NOT silently execute using a weak fallback
```

Instead:

``` text
clarify
```

or use a clearly configured development-only fallback.

Safety is more important than task completion.

------------------------------------------------------------------------

# 33. Phase 19 --- Cross-App Generalization

Separate:

``` text
workflow semantics
```

from:

``` text
app-specific implementation
```

Universal flow:

``` text
SEARCH
 ↓
RESULT
 ↓
PRODUCT
 ↓
ADD_TO_CART
 ↓
QUANTITY
 ↓
ADDRESS
 ↓
CHECKOUT
```

Different applications should map their Accessibility trees to the same
ontology.

The workflow may contain:

``` text
preferred_app
```

but must not depend exclusively on that app's resource IDs.

------------------------------------------------------------------------

# 34. Phase 20 --- Accessibility Bridge Hardening

Review:

``` text
MainActivity.kt
SaarAccessibilityService.kt
accessibility_bridge.dart
```

Ensure:

-   null-safe tree retrieval
-   native failures return explicit failure
-   no arbitrary command execution
-   actions are validated before dispatch
-   AccessibilityService state is observable
-   gestures are deterministic
-   text input is controlled
-   sensitive checks occur immediately before execution

Never cache a stale UI node and blindly execute it later.

Always re-ground against the current tree.

------------------------------------------------------------------------

# 35. Phase 21 --- Testing

Create unit tests for:

``` text
Flow serialization
Flow deserialization
slot extraction
intent parsing
confidence calculation
ambiguity detection
role matching
node ranking
screen hashing
credential guard
payment guard
recovery selection
execution reports
```

Create integration tests for:

``` text
Flutter → MethodChannel → AccessibilityService
```

Create physical-device end-to-end tests for:

``` text
teach
replay
paraphrase
slots
popup
scroll
stuck
clarification
credential stop
unknown
ambiguity
```

------------------------------------------------------------------------

# 36. Samsung PRISM Evaluation Matrix

Maintain:

``` text
docs/prism-test-matrix.md
```

Tests:

``` text
T1  Teach food workflow
T2  Exact replay
T3  Paraphrase
T4  Item slot
T5  Quantity slot
T6  Address slot
T7  Screen change / popup
T8  Teach ecommerce workflow
T9  Cross-app / slot replay
T10 Genuinely stuck
T11 Credential boundary
T12 Unknown intent
T13 Ambiguity
T14 Reporting
```

Each test must contain:

``` text
Setup
Command
Expected behavior
Observed behavior
Result
Evidence
Failure reason
Fix
```

Do not mark PASS without actually running the scenario.

------------------------------------------------------------------------

# 37. T1--T14 Acceptance Requirements

## T1

Teach a workflow from a real demonstration.

Expected:

``` text
Accessibility trace
→ filtering
→ synthesized semantic flow
→ saved flow
```

## T2

Replay the same command.

Expected:

``` text
correct flow
→ correct targets
→ successful completion
```

## T3

Use a paraphrase.

Expected:

``` text
same learned flow
```

## T4

Change item.

Expected:

``` text
item slot replaced
```

## T5

Change quantity.

Expected:

``` text
quantity slot replaced
```

## T6

Change address.

Expected:

``` text
address slot resolved
```

## T7

Introduce screen/popup change.

Expected:

``` text
detect
→ recover
→ continue
```

## T8

Teach another workflow.

Expected:

``` text
second flow saved independently
```

## T9

Test semantic generalization.

Expected:

``` text
workflow semantics remain stable
```

## T10

Make the target genuinely unavailable.

Expected:

``` text
ask user
→ receive clarification
→ resume same step
```

## T11

Expose credential/payment screen.

Expected:

``` text
hard stop
```

No credentials may be entered.

## T12

Give an unknown command.

Expected:

``` text
UNKNOWN
→ no automation
→ ask to teach
```

## T13

Give an ambiguous command.

Expected:

``` text
clarification
```

No silent guess.

## T14

Show execution report.

Expected:

``` text
step
status
recovery
clarification
stop reason
```

------------------------------------------------------------------------


# 39. Judge-Facing Differentiators

The implementation should emphasize:

## 1. One-shot learning

The user demonstrates a task once.

## 2. Semantic workflows

The system learns roles, not coordinates.

## 3. Natural-language generalization

Paraphrases map to the same workflow.

## 4. Slot abstraction

Item, quantity and address are variables.

## 5. State-aware replay

Actions are grounded against the current screen.

## 6. Recovery

Popups and changed screens do not automatically destroy the workflow.

## 7. Clarification

The system asks instead of guessing.

## 8. Safety

Credentials and payments are hard boundaries.

## 9. On-device intelligence

Core intent understanding does not require Claude at runtime.

## 10. Cross-app semantics

The workflow representation is independent of one app's resource IDs.

------------------------------------------------------------------------

# 40. Do Not Implement These Anti-Patterns

Never:

``` text
blindly replay coordinates
```

Never:

``` text
let an LLM directly control AccessibilityService
```

Never:

``` text
execute if model confidence is low
```

Never:

``` text
silently choose between ambiguous flows
```

Never:

``` text
enter passwords or OTPs
```

Never:

``` text
automate payment
```

Never:

``` text
store sensitive credentials in logs
```

Never:

``` text
hard-code a Claude model as the only runtime intelligence
```

Never:

``` text
claim a benchmark result without measuring it
```

------------------------------------------------------------------------

# 41. Priority Order

The coding agent MUST implement in this order.

## P0 --- Reliability and Safety

1.  Migration to main
2.  Baseline build
3.  configuration cleanup
4.  ReplaySession
5.  pause/resume
6.  ScreenSnapshot
7.  preconditions/postconditions
8.  RecoveryEngine
9.  semantic node ranking
10. credential/payment hard stop
11. STOP button
12. execution reporting

## P1 --- Intelligence

13. ParsedIntent
14. SlotExtractor
15. improved FlowMatcher
16. structured reranking
17. ambiguity detection
18. unknown intent
19. better embeddings

## P2 --- Own Model

20. dataset tooling
21. Claude teacher pipeline
22. dataset validation
23. SAAR-NLU
24. intent head
25. slot head
26. embedding head
27. evaluation
28. ONNX export
29. quantization
30. Android local inference

## P3 --- Differentiation

31. cross-app semantic transfer
32. app capability profiles
33. stronger state reasoning
34. adaptive recovery
35. richer reporting

## P4 --- Submission

36. full T1--T14 run
37. bug fixing
38. release APK
39. architecture document
40. safety document
41. limitations document
42. five-minute demo
43. final repository cleanup

------------------------------------------------------------------------

# 42. Definition of Done

The project is NOT considered complete until all of the following are
true:

``` text
[ ] revamp/flutter architecture is on main
[ ] old competing Android module removed
[ ] debug build succeeds
[ ] release build succeeds
[ ] physical-device test succeeds
[ ] AccessibilityService works
[ ] teach mode works
[ ] learned flow persists
[ ] exact replay works
[ ] paraphrase works
[ ] item slot works
[ ] quantity slot works
[ ] address slot works
[ ] popup recovery works
[ ] scroll recovery works
[ ] changed-screen detection works
[ ] ReplaySession pauses correctly
[ ] clarification resumes the SAME step
[ ] unknown intent does not execute
[ ] ambiguity causes clarification
[ ] credential guard is fail-closed
[ ] OTP guard is fail-closed
[ ] payment boundary is fail-closed
[ ] STOP button works
[ ] execution report works
[ ] sensitive data is not logged
[ ] real API keys are not committed
[ ] Claude is not required for core runtime intelligence
[ ] SAAR-NLU model exists
[ ] SAAR-NLU is evaluated
[ ] SAAR-NLU can run locally
[ ] model is integrated into Android
[ ] cross-app semantic design is implemented/tested where feasible
[ ] T1 passes
[ ] T2 passes
[ ] T3 passes
[ ] T4 passes
[ ] T5 passes
[ ] T6 passes
[ ] T7 passes
[ ] T8 passes
[ ] T9 passes
[ ] T10 passes
[ ] T11 passes
[ ] T12 passes
[ ] T13 passes
[ ] T14 passes
[ ] final APK generated
[ ] final demo recorded
[ ] repository cleaned
```

------------------------------------------------------------------------

# 43. Coding-Agent Operating Procedure

For EVERY implementation phase:

### Step 1

Inspect the existing code.

### Step 2

Identify affected files.

### Step 3

Implement the smallest coherent change.

### Step 4

Run formatting:

``` bash
dart format .
```

### Step 5

Run:

``` bash
flutter analyze
```

### Step 6

Run relevant tests:

``` bash
flutter test
```

### Step 7

If Android/native code changed:

``` bash
flutter build apk --debug
```

### Step 8

Run on a physical Android device when the feature requires
AccessibilityService behavior.

### Step 9

Document the result.

### Step 10

Only then move to the next phase.

------------------------------------------------------------------------

# 45. Final Product Definition

The final SAAR system should behave like this:

``` text
User:
"Order two packets of rice."

        ↓

SAAR-NLU:
intent = order_item
item = rice
quantity = 2
confidence = high

        ↓

FlowMatcher:
select learned food-order workflow

        ↓

ReplaySession:
create session

        ↓

AccessibilityService:
read current UI

        ↓

Semantic Grounder:
SEARCH_FIELD found

        ↓

Safety:
safe

        ↓

Execute:
tap search

        ↓

Verify:
search screen appeared

        ↓

Execute:
enter "rice"

        ↓

Verify:
results appeared

        ↓

Execute:
select semantic RESULT_ITEM

        ↓

Popup appears

        ↓

RecoveryEngine:
detect harmless popup

        ↓

Dismiss

        ↓

Continue

        ↓

Quantity:
set 2

        ↓

Address:
resolve requested address

        ↓

Checkout

        ↓

Payment screen detected

        ↓

CredentialGuard:
BLOCK

        ↓

User:
sees execution report

        ↓

SAAR:
"Automation stopped before payment for safety."
```

------------------------------------------------------------------------

# 46. Final Engineering Principle

The project should optimize for:

``` text
                 TRUSTWORTHY AUTOMATION

       Understand
            +
       Semantic grounding
            +
       State awareness
            +
       Recovery
            +
       User clarification
            +
       Deterministic safety
            =
       Reliable SAAR
```

The goal is NOT to make an AI that can click everything.

The goal is to make an agent that can:

``` text
LEARN
UNDERSTAND
GENERALIZE
GROUND
EXECUTE
RECOVER
ASK
STOP SAFELY
REPORT
```

That is the implementation target for the final Samsung PRISM
submission.