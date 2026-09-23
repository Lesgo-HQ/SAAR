class TypedSlot {
  final String type;
  final dynamic value;
  const TypedSlot(this.type, this.value);
  Map<String, dynamic> toJson() => {'type': type, 'value': value};
}

class SlotExtractor {
  static final _quantityRe = RegExp(r'\b(\d+)\s*(kg|g|packets?|units?|pieces?|x)?\b', caseSensitive: false);
  static const _wordNums = {'one':1,'two':2,'three':3,'four':4,'five':5,'six':6,'seven':7,'eight':8,'nine':9,'ten':10};

  Map<String, dynamic> extract(String text) {
    final m = <String, dynamic>{};
    final lower = text.toLowerCase();
    final qty = _extractQuantity(lower);
    if (qty != null) m['quantity'] = qty;
    final item = _extractItem(lower);
    if (item != null) m['item'] = item;
    final addr = _extractAddress(lower);
    if (addr != null) m['address'] = addr;
    return m;
  }

  Map<String, dynamic> extractTyped(String text) {
    final raw = extract(text);
    return raw.map((k,v) => MapEntry(k, k=='quantity' ? TypedSlot('integer', v).toJson() : TypedSlot('string', v).toJson()));
  }

  int? _extractQuantity(String lower) {
    for (final e in _wordNums.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    final m = _quantityRe.firstMatch(lower);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  String? _extractItem(String lower) {
    final addrKeywords = ['office','home','work','delivery'];
    if (addrKeywords.any(lower.contains) && !lower.contains('order') && !lower.contains('buy')) return null;
    final itemPat = RegExp(r'(?:order|buy|get|add|search(?: for)?)\s+(?:\d+\s*(?:kg|g|packets?|units?)?\s*)?(.+?)(?:\s+from\s+\w+)?\s*$');
    final m = itemPat.firstMatch(lower);
    if (m != null) {
      var item = m.group(1)!.trim().replaceAll(RegExp(r'\s+from\s+\w+\s*$'), '').trim();
      item = item.replaceAll(RegExp(r'^\d+\s*(kg|g|packets?|units?)?\s*'), '').trim();
      if (item.isNotEmpty && item.length < 40) return item;
    }
    return null;
  }

  String? _extractAddress(String lower) {
    if (lower.contains('office')) return 'office';
    if (lower.contains('home')) return 'home';
    if (RegExp(r'deliver.*office').hasMatch(lower)) return 'office';
    if (RegExp(r'deliver.*home').hasMatch(lower)) return 'home';
    if (lower.contains('work')) return 'office';
    return null;
  }
}
