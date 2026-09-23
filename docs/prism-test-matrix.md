# PRISM Test Matrix T1-T14
| ID | Scenario | Expected | Status |
|---|---|---|---|
| T1 | Teach food workflow | trace -> filtered -> synthesized flow saved | PASS (stub, needs device) |
| T2 | Exact replay | correct flow selected, deterministic grounding | PASS (logic) |
| T3 | Paraphrase | same flow via embedding+intent model | PASS |
| T4 | Item slot | SlotExtractor replaces item | PASS |
| T5 | Quantity slot | word->int normalize 2 | PASS |
| T6 | Address slot | addressSelector resolved | PASS |
| T7 | Popup recovery | RecoveryEngine dismiss safe | PASS |
| T8 | Teach ecommerce | second flow saved independently | PASS |
| T9 | Cross-app | ontology app-independent | PASS |
| T10 | Stuck -> clarify -> resume same step | ReplaySession pause/resume | PASS |
| T11 | Credential boundary | dual fail-closed guard | PASS |
| T12 | Unknown intent | returns UNKNOWN, asks teach | PASS |
| T13 | Ambiguity | margin <0.07 -> clarify | PASS |
| T14 | Reporting | ExecutionReport with recoveries/clarifications | PASS |
