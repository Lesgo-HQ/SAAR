import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/flow.dart';
import 'package:saar/models/replay_session.dart';
import 'package:saar/models/screen_snapshot.dart';
import 'package:saar/models/ui_node.dart';
import 'package:saar/services/credential_guard.dart';

UiNode node({String? text, bool clickable = false, int left = 0}) => UiNode(
      text: text,
      packageName: 'com.example.shop',
      bounds: {'left': left, 'top': 0, 'right': left + 10, 'bottom': 10},
      isClickable: clickable,
      isEditable: false,
      isScrollable: false,
      isCheckable: false,
      isChecked: false,
      isFocusable: false,
      isFocused: false,
      inputType: 0,
      children: const [],
    );

void main() {
  test('screen hash ignores coordinates', () {
    final first = ScreenSnapshot.fromTree(node(text: 'Cart', left: 0), rolesForNode: (_) => ['CART']);
    final second = ScreenSnapshot.fromTree(node(text: 'Cart', left: 500), rolesForNode: (_) => ['CART']);
    expect(first.stateHash, second.stateHash);
  });

  test('replay session resumes without rewinding', () {
    final flow = Flow(
      flowId: 'flow',
      appPackage: 'com.example.shop',
      triggerIntent: 'order rice',
      exampleUtterances: const ['order rice'],
      slots: const [],
      steps: [FlowStep(id: 4, action: 'tap', targetRole: 'ADD_TO_CART')],
    );
    final session = ReplaySession(runId: 'run', flow: flow, slots: const {}, currentStep: 3)..start();
    session.pause();
    session.resume();
    expect(session.currentStep, 3);
    expect(session.status, ReplayStatus.executing);
  });

  test('credential guard blocks a payment boundary', () {
    expect(CredentialGuard.isSensitiveScreen(null), isTrue);
    expect(CredentialGuard.isSensitiveScreen(node(text: 'Place order', clickable: true)), isTrue);
  });
}
