import 'ui_node.dart';

class RoleOntology {
  static const String searchField = 'SEARCH_FIELD';
  static const String searchSubmit = 'SEARCH_SUBMIT';
  static const String resultList = 'RESULT_LIST';
  static const String resultItem = 'RESULT_ITEM';
  static const String productCard = 'PRODUCT_CARD';
  static const String productDetail = 'PRODUCT_DETAIL';
  static const String primaryAction = 'PRIMARY_ACTION';
  static const String addToCart = 'ADD_TO_CART';
  static const String cart = 'CART';
  static const String checkout = 'CHECKOUT';
  static const String quantityIncrease = 'QUANTITY_INCREASE';
  static const String quantityDecrease = 'QUANTITY_DECREASE';
  static const String quantityValue = 'QUANTITY_VALUE';
  static const String quantityStepper = 'QUANTITY_STEPPER';
  static const String addressSelector = 'ADDRESS_SELECTOR';
  static const String addressOption = 'ADDRESS_OPTION';
  static const String filter = 'FILTER';
  static const String sort = 'SORT';
  static const String navigation = 'NAVIGATION';
  static const String back = 'BACK';
  static const String dismiss = 'DISMISS';
  static const String confirm = 'CONFIRM';
  static const String login = 'LOGIN';
  static const String password = 'PASSWORD';
  static const String otp = 'OTP';
  static const String payment = 'PAYMENT';
  static const String pay = 'PAY';
  static const String placeOrder = 'PLACE_ORDER';

  static const String searchBox = searchField;
  static const String firstSearchResult = resultItem;
  static const String resultCard = productCard;
  static const String addToCartButton = addToCart;
  static const String deliveryAddress = addressSelector;
  static const String payButton = pay;
  static const String paymentScreen = payment;
  static const String otpField = otp;
  static const String passwordField = password;
  static const String loginScreen = login;
  static const String popupDismiss = dismiss;
  static const String cartIcon = cart;
  static const String checkoutButton = checkout;

  static const List<String> all = [
    searchField, searchSubmit, resultList, resultItem, productCard, productDetail,
    primaryAction, addToCart, cart, checkout, quantityIncrease, quantityDecrease,
    quantityValue, quantityStepper, addressSelector, addressOption, filter, sort,
    navigation, back, dismiss, confirm, login, password, otp, payment, pay, placeOrder,
  ];

  static String? inferRole(UiNode node) {
    double best = 0;
    String? bestRole;
    for (final r in all) {
      final s = matchScore(node, r);
      if (s > best) { best = s; bestRole = r; }
    }
    return best > 0.5 ? bestRole : null;
  }

  static double matchScore(UiNode node, String targetRole) {
    final text = node.text?.toLowerCase() ?? '';
    final desc = node.contentDescription?.toLowerCase() ?? '';
    final resId = node.resourceId?.toLowerCase() ?? '';
    final cls = node.className?.toLowerCase() ?? '';
    final inputType = node.inputType;
    double s = 0;
    switch (targetRole) {
      case searchField:
        if (cls.contains('edittext')) s += 0.4;
        if (resId.contains('search')) s += 0.4;
        if (desc.contains('search')) s += 0.3;
        if (text.contains('search')) s += 0.3;
        break;
      case searchSubmit:
        if (node.isClickable) s += 0.2;
        if (resId.contains('search')) s += 0.4;
        if (text.contains('search') || desc.contains('search')) s += 0.4;
        if (cls.contains('button') || cls.contains('imageview')) s += 0.2;
        break;
      case resultList:
        if (cls.contains('recyclerview') || cls.contains('listview')) s += 0.6;
        if (resId.contains('result') || resId.contains('list')) s += 0.3;
        break;
      case resultItem:
      case productCard:
        if (node.isClickable) s += 0.2;
        if (resId.contains('result') || resId.contains('product') || resId.contains('card') || resId.contains('item')) s += 0.4;
        if (desc.contains('product')) s += 0.3;
        break;
      case productDetail:
        if (resId.contains('detail') || resId.contains('product')) s += 0.4;
        if (text.contains('add to cart') || text.contains('buy')) s += 0.2;
        break;
      case primaryAction:
        if (node.isClickable) s += 0.3;
        if (cls.contains('button')) s += 0.3;
        if (text.contains('add') || text.contains('buy')) s += 0.3;
        break;
      case addToCart:
        if (cls.contains('button') || node.isClickable) s += 0.3;
        if (text.contains('add to cart') || text.contains('add to bag')) s += 0.6;
        if (resId.contains('cart') || resId.contains('add')) s += 0.3;
        break;
      case cart:
        if (node.isClickable) s += 0.2;
        if (resId.contains('cart') || resId.contains('basket')) s += 0.5;
        if (desc.contains('cart') || desc.contains('basket')) s += 0.5;
        break;
      case checkout:
        if (cls.contains('button') || node.isClickable) s += 0.2;
        if (text.contains('checkout')) s += 0.6;
        if (resId.contains('checkout')) s += 0.4;
        break;
      case quantityIncrease:
        if (node.isClickable) s += 0.2;
        if (text.contains('+') || desc.contains('increase') || resId.contains('increase') || resId.contains('plus')) s += 0.5;
        break;
      case quantityDecrease:
        if (node.isClickable) s += 0.2;
        if (text.contains('-') || text.contains('−') || desc.contains('decrease') || resId.contains('decrease') || resId.contains('minus')) s += 0.5;
        break;
      case quantityValue:
        if (cls.contains('textview') || cls.contains('edittext')) s += 0.2;
        if (RegExp(r'^\d+$').hasMatch(text.trim())) s += 0.4;
        if (resId.contains('quantity') || resId.contains('qty')) s += 0.3;
        break;
      case quantityStepper:
        if (resId.contains('quantity') || resId.contains('qty') || resId.contains('stepper')) s += 0.4;
        if (text.contains('+') || text.contains('-')) s += 0.2;
        break;
      case addressSelector:
      case addressOption:
        if (node.isClickable) s += 0.2;
        if (resId.contains('address')) s += 0.4;
        if (text.contains('address') || desc.contains('address')) s += 0.4;
        break;
      case filter:
        if (text.contains('filter') || resId.contains('filter') || desc.contains('filter')) s += 0.6;
        break;
      case sort:
        if (text.contains('sort') || resId.contains('sort') || desc.contains('sort')) s += 0.6;
        break;
      case navigation:
        if (cls.contains('bottomnavigation') || resId.contains('navigation') || resId.contains('nav_')) s += 0.5;
        break;
      case back:
        if (text.contains('back') || desc.contains('back') || resId.contains('back') || resId.contains('navigate_up')) s += 0.5;
        break;
      case dismiss:
        if (node.isClickable) s += 0.2;
        if (resId.contains('close') || resId.contains('dismiss') || resId.contains('cancel')) s += 0.5;
        if (text == 'x' || text == 'close' || text == 'cancel' || desc.contains('close')) s += 0.5;
        break;
      case confirm:
        if (node.isClickable) s += 0.3;
        if (text.contains('confirm') || text.contains('ok') || text.contains('yes')) s += 0.5;
        break;
      case login:
        if (text.contains('login') || text.contains('sign in') || resId.contains('login') || desc.contains('login')) s += 0.6;
        break;
      case password:
        if (cls.contains('edittext')) s += 0.2;
        if (inputType == 128 || inputType == 144 || inputType == 224 || inputType == 16) s += 0.8;
        if (resId.contains('password') || resId.contains('passwd')) s += 0.5;
        if (text.contains('password')) s += 0.4;
        break;
      case otp:
        if (cls.contains('edittext')) s += 0.2;
        if (resId.contains('otp') || resId.contains('pin') || resId.contains('verification')) s += 0.6;
        if (text.contains('otp') || text.contains('pin')) s += 0.4;
        break;
      case payment:
        if (text.contains('payment') || resId.contains('payment') || desc.contains('payment')) s += 0.6;
        break;
      case pay:
        if (cls.contains('button') || node.isClickable) s += 0.3;
        if (text.contains('pay') || text.contains('place order') || text.contains('confirm')) s += 0.6;
        if (resId.contains('pay') || resId.contains('order')) s += 0.4;
        break;
      case placeOrder:
        if (node.isClickable) s += 0.3;
        if (text.contains('place order')) s += 0.7;
        if (resId.contains('place_order') || resId.contains('placeorder')) s += 0.5;
        break;
      default:
        if (resId.contains(targetRole.toLowerCase().replaceAll('_', ''))) s += 0.4;
        if (text.contains(targetRole.toLowerCase().replaceAll('_', ' '))) s += 0.4;
        if (desc.contains(targetRole.toLowerCase().replaceAll('_', ' '))) s += 0.4;
        break;
    }
    return s > 1 ? 1 : s;
  }
}
