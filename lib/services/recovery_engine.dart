import '../models/ui_node.dart';
import 'accessibility_bridge.dart';

enum RecoveryAction { refreshed, dismissedPopup, scrolled, unavailable }

class RecoveryResult {
  final RecoveryAction action;
  final UiNode? tree;

  const RecoveryResult(this.action, this.tree);
  bool get recovered => action != RecoveryAction.unavailable;
}

class RecoveryEngine {
  final AccessibilityBridge _bridge;

  RecoveryEngine(this._bridge);

  Future<RecoveryResult> recover(UiNode tree) async {
    final refreshed = await _bridge.getLastTree();
    final current = refreshed ?? tree;
    if (await _dismissSafePopup(current)) {
      return RecoveryResult(RecoveryAction.dismissedPopup, await _bridge.getLastTree());
    }
    if (await _scroll(current)) {
      return RecoveryResult(RecoveryAction.scrolled, await _bridge.getLastTree());
    }
    return refreshed == null ? const RecoveryResult(RecoveryAction.unavailable, null) : RecoveryResult(RecoveryAction.refreshed, refreshed);
  }

  Future<bool> _dismissSafePopup(UiNode tree) async {
    const safe = {'ok', 'close', 'dismiss', 'not now', 'skip', 'later', 'no thanks', 'got it'};
    const blocked = {'pay', 'purchase', 'place order', 'delete', 'remove account', 'transfer', 'send money'};
    for (final node in tree.flatten()) {
      final label = '${node.text ?? ''} ${node.contentDescription ?? ''}'.toLowerCase().trim();
      if (!node.isClickable || !safe.contains(label) || blocked.any(label.contains)) continue;
      final bounds = node.bounds;
      return _bridge.tap(((bounds['left'] ?? 0) + (bounds['right'] ?? 0)) / 2, ((bounds['top'] ?? 0) + (bounds['bottom'] ?? 0)) / 2);
    }
    return false;
  }

  Future<bool> _scroll(UiNode tree) async {
    for (final node in tree.flatten()) {
      if (!node.isScrollable) continue;
      final bounds = node.bounds;
      final x = ((bounds['left'] ?? 0) + (bounds['right'] ?? 0)) / 2;
      final y = ((bounds['top'] ?? 0) + (bounds['bottom'] ?? 0)) / 2;
      return _bridge.swipe(x, y + 300, x, y - 300, durationMs: 300);
    }
    return false;
  }
}
