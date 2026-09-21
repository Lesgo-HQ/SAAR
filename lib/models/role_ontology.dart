import 'ui_node.dart';

class RoleOntology {
  static const String searchBox = 'search_box';
  static const String firstSearchResult = 'first_search_result';
  static const String resultCard = 'result_card';
  static const String addToCartButton = 'add_to_cart_button';
  static const String quantityStepper = 'quantity_stepper';
  static const String deliveryAddress = 'delivery_address';
  static const String addressSelector = 'address_selector';
  static const String payButton = 'pay_button';
  static const String paymentScreen = 'payment_screen';
  static const String otpField = 'otp_field';
  static const String passwordField = 'password_field';
  static const String loginScreen = 'login_screen';
  static const String popupDismiss = 'popup_dismiss';
  static const String cartIcon = 'cart_icon';
  static const String checkoutButton = 'checkout_button';

  static const List<String> all = [
    searchBox,
    firstSearchResult,
    resultCard,
    addToCartButton,
    quantityStepper,
    deliveryAddress,
    addressSelector,
    payButton,
    paymentScreen,
    otpField,
    passwordField,
    loginScreen,
    popupDismiss,
    cartIcon,
    checkoutButton,
  ];

  static String? inferRole(UiNode node) {
    double bestScore = 0.0;
    String? bestRole;

    for (String role in all) {
      double score = matchScore(node, role);
      if (score > bestScore) {
        bestScore = score;
        bestRole = role;
      }
    }

    if (bestScore > 0.5) {
      return bestRole;
    }
    return null;
  }

  static double matchScore(UiNode node, String targetRole) {
    final String text = node.text?.toLowerCase() ?? '';
    final String desc = node.contentDescription?.toLowerCase() ?? '';
    final String resId = node.resourceId?.toLowerCase() ?? '';
    final String className = node.className?.toLowerCase() ?? '';
    final int inputType = node.inputType;

    double score = 0.0;

    switch (targetRole) {
      case searchBox:
        if (className.contains('edittext')) score += 0.4;
        if (resId.contains('search')) score += 0.4;
        if (desc.contains('search')) score += 0.3;
        if (text.contains('search')) score += 0.3;
        break;

      case addToCartButton:
        if (className.contains('button') || node.isClickable) score += 0.3;
        if (text.contains('add to cart') || text.contains('add to bag')) score += 0.6;
        if (resId.contains('cart') || resId.contains('add')) score += 0.3;
        break;

      case payButton:
        if (className.contains('button') || node.isClickable) score += 0.3;
        if (text.contains('pay') || text.contains('place order') || text.contains('confirm')) score += 0.6;
        if (resId.contains('pay') || resId.contains('order')) score += 0.4;
        break;

      case passwordField:
        if (className.contains('edittext')) score += 0.2;
        if (inputType == 128 || inputType == 144 || inputType == 224 || inputType == 16) score += 0.8;
        if (resId.contains('password') || resId.contains('passwd')) score += 0.5;
        if (text.contains('password')) score += 0.4;
        break;

      case otpField:
        if (className.contains('edittext')) score += 0.2;
        if (resId.contains('otp') || resId.contains('pin') || resId.contains('verification')) score += 0.6;
        if (text.contains('otp') || text.contains('pin')) score += 0.4;
        break;

      case cartIcon:
        if (node.isClickable) score += 0.2;
        if (resId.contains('cart') || resId.contains('basket')) score += 0.5;
        if (desc.contains('cart') || desc.contains('basket')) score += 0.5;
        break;
        
      case checkoutButton:
        if (className.contains('button') || node.isClickable) score += 0.2;
        if (text.contains('checkout')) score += 0.6;
        if (resId.contains('checkout')) score += 0.4;
        break;

      case popupDismiss:
        if (node.isClickable) score += 0.2;
        if (resId.contains('close') || resId.contains('dismiss') || resId.contains('cancel')) score += 0.5;
        if (text == 'x' || text == 'close' || text == 'cancel') score += 0.5;
        break;
        
      default:
        if (resId.contains(targetRole.replaceAll('_', ''))) score += 0.4;
        if (text.contains(targetRole.replaceAll('_', ' '))) score += 0.4;
        if (desc.contains(targetRole.replaceAll('_', ' '))) score += 0.4;
        break;
    }

    return score > 1.0 ? 1.0 : score;
  }
}
