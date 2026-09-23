import 'dart:math' as math;
import '../models/parsed_intent.dart';
import 'slot_extractor.dart';

abstract class IntentModel {
  Future<ParsedIntent> parse(String text);
  Future<List<double>> embed(String text);
}

class LocalIntentModel implements IntentModel {
  final SlotExtractor _extractor = SlotExtractor();
  static const _intents = ['order_item','search_item','add_to_cart','change_quantity','checkout','select_address'];
  static const _unknownTrigger = ['joke','weather','camera','music','message','flight','call','open camera','play music','tell me'];

  @override
  Future<ParsedIntent> parse(String text) async {
    final lower = text.toLowerCase().trim();
    if (_unknownTrigger.any(lower.contains)) return ParsedIntent.unknown();
    final slots = _extractor.extract(lower);
    String intent = 'UNKNOWN';
    double conf = 0;
    if (RegExp(r'\border\b|\bbuy\b|\border.*rice\b|\border.*milk\b').hasMatch(lower)) { intent='order_item'; conf=0.9; }
    else if (RegExp(r'\bsearch\b').hasMatch(lower)) { intent='search_item'; conf=0.85; }
    else if (RegExp(r'add.*cart').hasMatch(lower)) { intent='add_to_cart'; conf=0.85; }
    else if (RegExp(r'quantity|how many|change.*qty').hasMatch(lower)) { intent='change_quantity'; conf=0.8; }
    else if (RegExp(r'checkout|place order|pay').hasMatch(lower)) { intent='checkout'; conf=0.8; }
    else if (RegExp(r'deliver|address|office|home').hasMatch(lower)) { intent='select_address'; conf=0.75; }
    else if (slots.isNotEmpty) { intent='order_item'; conf=0.55; }
    else return ParsedIntent.unknown(confidence: 0.4);
    String? app;
    if (lower.contains('zepto')) app='zepto';
    else if (lower.contains('amazon')) app='amazon';
    else if (lower.contains('flipkart')) app='flipkart';
    return ParsedIntent(intent: intent, app: app, slots: slots, confidence: conf);
  }

  @override
  Future<List<double>> embed(String text) async {
    final v = List<double>.filled(128, 0.0);
    for (final t in text.toLowerCase().split(RegExp(r'\W+')).where((e)=>e.isNotEmpty)) v[t.hashCode.abs()%128]+=1;
    double s=0; for (final x in v) s+=x*x;
    final mag = s>0? math.sqrt(s):1;
    return v.map((e)=>e/mag).toList();
  }
}
