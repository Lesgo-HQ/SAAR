import '../models/ui_node.dart';

class CredentialGuard {
  /// Check if the current UI tree contains any sensitive fields.
  /// This is FAIL-CLOSED: if anything goes wrong, returns true (sensitive detected).
  static bool isSensitiveScreen(UiNode? rootNode) {
    if (rootNode == null) return true; // fail closed
    try {
      final allNodes = rootNode.flatten();
      return allNodes.any((node) => _isSensitiveNode(node));
    } catch (_) {
      return true; // fail closed
    }
  }
  
  static bool _isSensitiveNode(UiNode node) {
    // Check inputType flags for password variants
    final inputType = node.inputType;
    final maskedVariation = inputType & 0xFF0;
    const passwordVariations = [0x80, 0x90, 0xE0, 0x10];
    if (passwordVariations.contains(maskedVariation)) return true;
    
    // Check resourceId patterns (case-insensitive)
    final rid = (node.resourceId ?? '').toLowerCase();
    const sensitiveIdPatterns = ['password', 'passwd', 'otp', 'pin', 'cvv', 'card_number', 
      'credit_card', 'debit_card', 'security_code', 'card_num', 'expiry', 'cvc'];
    if (sensitiveIdPatterns.any((p) => rid.contains(p))) return true;
    
    // Check className
    final cn = (node.className ?? '').toLowerCase();
    if (cn.contains('password')) return true;
    
    // Check contentDescription
    final cd = (node.contentDescription ?? '').toLowerCase();
    const sensitiveDescPatterns = ['password', 'otp', 'pin', 'cvv', 'card number', 
      'security code', 'verification code', 'credit card', 'debit card'];
    if (sensitiveDescPatterns.any((p) => cd.contains(p))) return true;
    
    // Check text (for login screens)
    final text = (node.text ?? '').toLowerCase();
    const loginPatterns = ['enter otp', 'enter pin', 'enter cvv', 'enter password',
      'verify otp', 'verification code'];
    if (loginPatterns.any((p) => text.contains(p))) return true;
    
    return false;
  }
  
  /// Returns a description of why the screen was flagged as sensitive
  static String? getSensitiveReason(UiNode? rootNode) {
    if (rootNode == null) return 'No UI tree available (fail-closed)';
    try {
      final allNodes = rootNode.flatten();
      for (final node in allNodes) {
        if (_isSensitiveNode(node)) {
          return 'Sensitive field detected: ${node.resourceId ?? node.className ?? node.text ?? 'unknown'}';
        }
      }
      return null;
    } catch (e) {
      return 'Error checking sensitivity: $e';
    }
  }
}
