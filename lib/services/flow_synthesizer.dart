import '../models/flow.dart';
import '../models/action_trace_event.dart';
import 'llm_client.dart';

class FlowSynthesizer {
  final LlmClient _llm;

  FlowSynthesizer(this._llm);

  /// Synthesize a Flow from action trace and user's utterance
  Future<Flow> synthesize(String utterance, List<ActionTraceEvent> trace) async {
    // 1. Filter noise from trace (drop non-task actions)
    final filtered = _filterNoise(trace);
    // 2. Convert to JSON-serializable format
    final traceJson = filtered.map((e) => e.toJson()).toList();
    // 3. Call LLM to synthesize
    return await _llm.synthesizeFlow(utterance, traceJson);
  }

  /// Filter noise from action trace.
  /// Drops actions unrelated to the dominant task:
  /// - System UI package events (notifications, launcher)
  /// - Duplicate taps within 100ms on same node
  /// - Notification shade interactions
  /// - Very rapid repeated actions
  List<ActionTraceEvent> _filterNoise(List<ActionTraceEvent> trace) {
    const systemPackages = [
      'com.android.systemui',
      'com.android.launcher3',
      'com.google.android.apps.nexuslauncher',
      'com.android.packageinstaller',
      'com.android.permissioncontroller',
    ];

    final filtered = <ActionTraceEvent>[];

    for (int i = 0; i < trace.length; i++) {
      final event = trace[i];

      // 1. Remove system package events
      if (event.packageName != null && systemPackages.contains(event.packageName)) {
        continue;
      }

      // 2. Remove duplicate actions within 100ms on same node
      if (filtered.isNotEmpty) {
        final lastEvent = filtered.last;
        final timeDiff = event.timestampMs - lastEvent.timestampMs;
        final sameNode = event.node?.nodeId != null &&
            event.node?.nodeId == lastEvent.node?.nodeId &&
            event.node!.nodeId!.isNotEmpty;
        if (timeDiff < 100 && sameNode && event.action == lastEvent.action) {
          continue;
        }
      }

      // 3. Remove notification shade interactions
      if (event.node != null) {
        final className = (event.node!.className ?? '').toLowerCase();
        final resourceId = (event.node!.resourceId ?? '').toLowerCase();
        if (className.contains('notification') || resourceId.contains('notification') ||
            resourceId.contains('status_bar') || className.contains('statusbar')) {
          continue;
        }
      }

      // 4. Skip focus events that are immediately followed by a tap or type on same node
      if (event.action == 'focus' && i + 1 < trace.length) {
        final nextEvent = trace[i + 1];
        if ((nextEvent.action == 'tap' || nextEvent.action == 'type') &&
            nextEvent.node?.nodeId == event.node?.nodeId) {
          continue; // skip redundant focus
        }
      }

      filtered.add(event);
    }

    return filtered;
  }
}
