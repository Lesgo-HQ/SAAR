import 'dart:async';
import '../models/flow.dart';
import '../models/ui_node.dart';
import '../models/role_ontology.dart';
import 'accessibility_bridge.dart';
import 'credential_guard.dart';
import 'llm_client.dart';
import 'clarification_service.dart';

enum ReplayStatus { idle, executing, paused, waitingForUser, completed, failed, halted }

class ReplayState {
  final ReplayStatus status;
  final int currentStep;
  final int totalSteps;
  final String? message;
  final String? clarificationQuestion;

  ReplayState({
    required this.status,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.message,
    this.clarificationQuestion,
  });
}

class ReplayEngine {
  final AccessibilityBridge _bridge;
  // Reserved for LLM-based adaptation in build phase 5
  // ignore: unused_field
  final LlmClient _llm;
  final ClarificationService _clarification;

  static const int _maxRetries = 2;
  static const Duration _stepDelay = Duration(milliseconds: 800);
  static const double _matchThreshold = 0.4;

  final _stateController = StreamController<ReplayState>.broadcast();
  Stream<ReplayState> get stateStream => _stateController.stream;

  bool _shouldStop = false;

  ReplayEngine(this._bridge, this._llm, this._clarification);

  /// Execute a flow with resolved slot values
  Future<ReplayState> execute(Flow flow, Map<String, dynamic> slotValues) async {
    _shouldStop = false;
    final totalSteps = flow.steps.length;

    for (int i = 0; i < flow.steps.length; i++) {
      if (_shouldStop) {
        _emit(ReplayState(
          status: ReplayStatus.halted,
          currentStep: i,
          totalSteps: totalSteps,
          message: 'Stopped by user',
        ));
        return ReplayState(status: ReplayStatus.halted);
      }

      final step = flow.steps[i];
      _emit(ReplayState(
        status: ReplayStatus.executing,
        currentStep: i + 1,
        totalSteps: totalSteps,
        message: 'Executing: ${step.action} on ${step.targetRole}',
      ));

      final result = await _executeStep(step, slotValues, i + 1, totalSteps);
      if (result.status == ReplayStatus.failed || result.status == ReplayStatus.halted) {
        return result;
      }

      await Future.delayed(_stepDelay);
    }

    _emit(ReplayState(
      status: ReplayStatus.completed,
      currentStep: totalSteps,
      totalSteps: totalSteps,
      message: 'Flow completed successfully',
    ));
    return ReplayState(status: ReplayStatus.completed);
  }

  Future<ReplayState> _executeStep(
    FlowStep step,
    Map<String, dynamic> slotValues,
    int stepNum,
    int totalSteps,
  ) async {
    // Handle stop_before action: pause and wait for user
    if (step.action == 'stop_before') {
      _emit(ReplayState(
        status: ReplayStatus.waitingForUser,
        currentStep: stepNum,
        totalSteps: totalSteps,
        message: 'Paused before: ${step.targetRole}. Please confirm to continue.',
        clarificationQuestion: 'Ready to proceed with ${step.targetRole}?',
      ));
      return ReplayState(status: ReplayStatus.paused);
    }

    int retries = 0;
    while (retries <= _maxRetries) {
      if (_shouldStop) {
        return ReplayState(status: ReplayStatus.halted, currentStep: stepNum, totalSteps: totalSteps);
      }

      // 1. Get current UI tree
      final tree = await _bridge.getLastTree();

      // 2. CREDENTIAL GUARD CHECK — halt if sensitive
      if (CredentialGuard.isSensitiveScreen(tree)) {
        final reason = CredentialGuard.getSensitiveReason(tree);
        _emit(ReplayState(
          status: ReplayStatus.halted,
          currentStep: stepNum,
          totalSteps: totalSteps,
          message: 'HALTED — Sensitive screen detected: $reason. Automation stopped for your safety.',
        ));
        return ReplayState(status: ReplayStatus.halted, currentStep: stepNum, totalSteps: totalSteps);
      }

      // Also check via native Kotlin credential guard (redundant, belt-and-suspenders)
      try {
        final nativeSensitive = await _bridge.isSensitiveScreen();
        if (nativeSensitive) {
          _emit(ReplayState(
            status: ReplayStatus.halted,
            currentStep: stepNum,
            totalSteps: totalSteps,
            message: 'HALTED — Native credential guard detected sensitive screen. Automation stopped.',
          ));
          return ReplayState(status: ReplayStatus.halted, currentStep: stepNum, totalSteps: totalSteps);
        }
      } catch (_) {
        // If native check fails, the Dart-side check above already ran
      }

      if (tree == null) {
        retries++;
        await Future.delayed(_stepDelay);
        continue;
      }

      // 3. Find best matching node for step.targetRole
      final targetNode = _findNodeByRole(tree, step.targetRole);

      if (targetNode != null) {
        // 4. Execute the action
        final success = await _performAction(step, targetNode, slotValues);
        if (success) {
          return ReplayState(
            status: ReplayStatus.executing,
            currentStep: stepNum,
            totalSteps: totalSteps,
          );
        }
        // Action failed — retry
        retries++;
        await Future.delayed(_stepDelay);
        continue;
      }

      // 5. No matching node — try adaptation
      // 5a. Try dismissing popup
      if (await _tryDismissPopup(tree)) {
        await Future.delayed(_stepDelay);
        retries++;
        continue;
      }

      // 5b. Try scrolling to find target
      if (await _tryScroll(tree, step.targetRole)) {
        await Future.delayed(_stepDelay);
        retries++;
        continue;
      }

      retries++;
      if (retries <= _maxRetries) {
        await Future.delayed(_stepDelay);
      }
    }

    // 6. All retries exhausted — ask user
    final question = _clarification.buildReplayClarification(
      '${step.action} on ${step.targetRole}',
      _describeScreen(await _bridge.getLastTree()),
    );
    _emit(ReplayState(
      status: ReplayStatus.waitingForUser,
      currentStep: stepNum,
      totalSteps: totalSteps,
      message: 'Stuck — could not find ${step.targetRole}',
      clarificationQuestion: question,
    ));
    return ReplayState(
      status: ReplayStatus.failed,
      currentStep: stepNum,
      totalSteps: totalSteps,
      message: 'Failed to find target element: ${step.targetRole}',
    );
  }

  /// Perform the actual action on a target node using the bridge
  Future<bool> _performAction(FlowStep step, UiNode targetNode, Map<String, dynamic> slotValues) async {
    // Calculate center coordinates from node bounds
    final bounds = targetNode.bounds;
    final centerX = ((bounds['left'] ?? 0) + (bounds['right'] ?? 0)) / 2.0;
    final centerY = ((bounds['top'] ?? 0) + (bounds['bottom'] ?? 0)) / 2.0;

    switch (step.action) {
      case 'tap':
        return await _bridge.tap(centerX, centerY);

      case 'type':
        // Resolve the value: use slot value if value_slot references a slot, otherwise use literal
        String value = '';
        if (step.valueSlot != null && slotValues.containsKey(step.valueSlot)) {
          value = slotValues[step.valueSlot].toString();
        } else if (step.valueLiteral != null) {
          value = step.valueLiteral!;
        }
        // First tap to focus the field
        await _bridge.tap(centerX, centerY);
        await Future.delayed(const Duration(milliseconds: 300));
        return await _bridge.typeIntoFocused(value);

      case 'set_quantity':
        // Tap on quantity stepper, then type value
        String value = '1';
        if (step.valueSlot != null && slotValues.containsKey(step.valueSlot)) {
          value = slotValues[step.valueSlot].toString();
        } else if (step.valueLiteral != null) {
          value = step.valueLiteral!;
        }
        await _bridge.tap(centerX, centerY);
        await Future.delayed(const Duration(milliseconds: 300));
        return await _bridge.typeIntoFocused(value);

      case 'select':
        return await _bridge.tap(centerX, centerY);

      case 'swipe':
        // Swipe up by default (scroll down) from center of node
        final startX = centerX;
        final startY = centerY;
        final endX = centerX;
        final endY = centerY - 300; // swipe up
        return await _bridge.swipe(startX, startY, endX, endY, durationMs: 300);

      default:
        return await _bridge.tap(centerX, centerY);
    }
  }

  /// Find the best matching node for a given role in the UI tree
  UiNode? _findNodeByRole(UiNode tree, String targetRole) {
    final nodes = tree.flatten();
    UiNode? bestNode;
    double bestScore = 0.0;

    for (var node in nodes) {
      final score = RoleOntology.matchScore(node, targetRole);
      if (score > bestScore && score >= _matchThreshold) {
        bestScore = score;
        bestNode = node;
      }
    }

    return bestNode;
  }

  /// Try to dismiss a popup/dialog by looking for common dismiss buttons
  Future<bool> _tryDismissPopup(UiNode tree) async {
    final nodes = tree.flatten();
    const dismissTexts = ['ok', 'cancel', 'dismiss', 'close', 'not now', 'skip', 'later', 'no thanks', 'got it'];

    for (var node in nodes) {
      if (!node.isClickable) continue;

      final text = (node.text ?? '').toLowerCase().trim();
      final desc = (node.contentDescription ?? '').toLowerCase().trim();
      final resId = (node.resourceId ?? '').toLowerCase();

      if (dismissTexts.contains(text) || dismissTexts.contains(desc) ||
          resId.contains('close') || resId.contains('dismiss') || resId.contains('cancel')) {
        final bounds = node.bounds;
        final cx = ((bounds['left'] ?? 0) + (bounds['right'] ?? 0)) / 2.0;
        final cy = ((bounds['top'] ?? 0) + (bounds['bottom'] ?? 0)) / 2.0;
        await _bridge.tap(cx, cy);
        return true;
      }
    }

    return false;
  }

  /// Try scrolling a scrollable container to find the target element
  Future<bool> _tryScroll(UiNode tree, String targetRole) async {
    final nodes = tree.flatten();
    for (var node in nodes) {
      if (node.isScrollable) {
        final bounds = node.bounds;
        final cx = ((bounds['left'] ?? 0) + (bounds['right'] ?? 0)) / 2.0;
        final topY = ((bounds['top'] ?? 0) + (bounds['bottom'] ?? 0)) / 2.0;
        final bottomY = topY + 300;
        // Swipe up to scroll down
        await _bridge.swipe(cx, bottomY.toDouble(), cx, topY.toDouble(), durationMs: 300);
        return true;
      }
    }
    return false;
  }

  /// Generate a brief description of the current screen for clarification messages
  String _describeScreen(UiNode? tree) {
    if (tree == null) return 'unknown screen';
    final nodes = tree.flatten();
    final clickableTexts = nodes
        .where((n) => n.isClickable && n.text != null && n.text!.isNotEmpty)
        .take(5)
        .map((n) => '"${n.text}"')
        .toList();
    if (clickableTexts.isEmpty) return 'a screen with no identifiable elements';
    return 'a screen showing: ${clickableTexts.join(', ')}';
  }

  void stop() {
    _shouldStop = true;
  }

  void _emit(ReplayState state) {
    _stateController.add(state);
  }

  void dispose() {
    _stateController.close();
  }
}
