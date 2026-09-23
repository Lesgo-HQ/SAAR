class ParsedIntent {
  final String intent;
  final String? app;
  final Map<String, dynamic> slots;
  final double confidence;
  const ParsedIntent({required this.intent, this.app, required this.slots, required this.confidence});
  factory ParsedIntent.unknown({double confidence = 0}) => ParsedIntent(intent: 'UNKNOWN', slots: const {}, confidence: confidence);
  bool get isUnknown => intent == 'UNKNOWN';
  Map<String, dynamic> toJson() => {'intent': intent, if (app != null) 'app': app, 'slots': slots, 'confidence': confidence};
  factory ParsedIntent.fromJson(Map<String, dynamic> j) => ParsedIntent(
    intent: j['intent'] as String, app: j['app'] as String?, slots: Map<String, dynamic>.from(j['slots'] as Map? ?? {}), confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
  );
}
