import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/flow.dart';

class IntentClassification {
  final String intent; // 'teach', 'command', 'unknown'
  final String? taskDescription; // what the user wants to do
  final Map<String, dynamic> extractedSlots; // slot values from utterance
  final double confidence;
  
  IntentClassification({
    required this.intent, 
    this.taskDescription, 
    this.extractedSlots = const {}, 
    this.confidence = 0.0,
  });
  
  factory IntentClassification.fromJson(Map<String, dynamic> json) {
    return IntentClassification(
      intent: json['intent'] as String? ?? 'unknown',
      taskDescription: json['task_description'] as String?,
      extractedSlots: (json['extracted_slots'] as Map<String, dynamic>?) ?? {},
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LlmClient {
  String _endpoint;
  String _apiKey;
  String _model;
  final String _embeddingEndpoint;
  
  LlmClient({
    String? endpoint,
    String? apiKey,
    String? model,
    String? embeddingEndpoint,
  }) : _endpoint = endpoint ?? dotenv.env['LLM_ENDPOINT'] ?? 'https://api.anthropic.com/v1/messages',
       _apiKey = apiKey ?? dotenv.env['LLM_API_KEY'] ?? '',
       _model = model ?? dotenv.env['LLM_MODEL'] ?? 'claude-3-5-sonnet-20241022',
       _embeddingEndpoint = embeddingEndpoint ?? dotenv.env['EMBEDDING_ENDPOINT'] ?? '';
  
  void updateConfig({String? endpoint, String? apiKey, String? model}) {
    if (endpoint != null) _endpoint = endpoint;
    if (apiKey != null) _apiKey = apiKey;
    if (model != null) _model = model;
  }
  
  /// Classify user intent from utterance + optional UI context
  static const String _classifyIntentSystemPrompt = '''
You are an intent classification engine for an Android accessibility assistant (SAAR).
Your task is to analyze the user's spoken utterance and optional UI context, and determine their intent.

The intent must be one of three categories:
1. "teach": The user wants to teach you a new automation or workflow.
2. "command": The user wants you to execute a known command or perform an action on the screen.
3. "unknown": The intent is unclear or not actionable.

You must also extract any slot values (e.g., item name, quantity, contact name, address, settings).
Output the response EXCLUSIVELY as valid JSON matching this schema:
{
  "intent": "teach" | "command" | "unknown",
  "task_description": "A clear, abstract description of the intended action",
  "extracted_slots": { "slot_key": "slot_value" },
  "confidence": <float between 0.0 and 1.0>
}
Do NOT include any text outside the JSON block.
''';

  Future<IntentClassification> classifyIntent(String utterance, {String? uiContextSummary}) async {
    final userMessage = uiContextSummary != null
        ? "Utterance: \"$utterance\"\nUI Context: $uiContextSummary"
        : "Utterance: \"$utterance\"";
        
    try {
      final response = await _callLlm(_classifyIntentSystemPrompt, userMessage);
      final llmResponseText = response['content'][0]['text'] as String;
      final parsedJson = _extractJson(llmResponseText);
      return IntentClassification.fromJson(jsonDecode(parsedJson));
    } catch (e) {
      debugPrint('Error classifying intent: $e');
      return IntentClassification(intent: 'unknown', confidence: 0.0);
    }
  }
  
  /// Synthesize a Flow from raw action trace
  static const String _synthesizeFlowSystemPrompt = '''
You are an intelligent agent that abstracts raw Android accessibility action traces into generalized, parameterized workflows (Flows) for an automation app (SAAR).

You will be given:
1. The user's intended task.
2. A raw JSON trace of Android accessibility actions {timestampMs, action, node, valueTyped}.

Your task:
- Abstract these actions into a logical sequence of generalized steps.
- Filter out noise (e.g., accidental taps, notification dismissals, scrolling that isn't part of the core task).
- Identify parameterized slots (values typed into fields or specific items clicked that might change next time).
- Map actions to standard roles (e.g., clicking a button, typing into a text field).
- Construct the final Flow object matching the provided Flow ontology/schema.

Output the Flow EXCLUSIVELY as valid JSON. Do not include markdown code blocks or explanatory text outside the JSON.
''';

  Future<Flow> synthesizeFlow(String utterance, List<Map<String, dynamic>> actionTrace) async {
    final userMessage = "Intended Task: \"$utterance\"\nAction Trace:\n${jsonEncode(actionTrace)}";
    
    try {
      final response = await _callLlm(_synthesizeFlowSystemPrompt, userMessage);
      final llmResponseText = response['content'][0]['text'] as String;
      final parsedJson = _extractJson(llmResponseText);
      return Flow.fromJson(jsonDecode(parsedJson));
    } catch (e) {
      debugPrint('Error synthesizing flow: $e');
      throw Exception('Failed to synthesize Flow from LLM: $e');
    }
  }
  
  /// Generate embedding vector for text
  /// Falls back to simple bag-of-words if API fails
  Future<List<double>> embed(String text) async {
    if (_embeddingEndpoint.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse(_embeddingEndpoint),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'},
          body: jsonEncode({'input': text}),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // Assuming OpenAI-like embedding response format
          return List<double>.from(data['data'][0]['embedding']);
        }
      } catch (e) {
        debugPrint('Embedding API failed, falling back to local bag-of-words: $e');
      }
    }
    
    // Fallback: Local normalized bag-of-words (128 dimensions)
    return _bagOfWordsEmbedding(text);
  }
  
  List<double> _bagOfWordsEmbedding(String text) {
    final vector = List<double>.filled(128, 0.0);
    final tokens = text.toLowerCase().split(RegExp(r'\W+')).where((t) => t.isNotEmpty);
    
    for (final token in tokens) {
      final hash = token.hashCode.abs();
      vector[hash % 128] += 1.0;
    }
    
    // Normalize vector
    double sumOfSquares = 0.0;
    for (final v in vector) {
      sumOfSquares += v * v;
    }
    final magnitude = sumOfSquares > 0 ? sqrt(sumOfSquares) : 1.0;
    
    return vector.map((v) => v / magnitude).toList();
  }
  
  // Private helper to make API call (Anthropic Messages API shape)
  Future<Map<String, dynamic>> _callLlm(String systemPrompt, String userMessage) async {
    if (_apiKey.isEmpty) {
      throw Exception('LLM API Key is not set.');
    }
    
    final payload = {
      "model": _model,
      "max_tokens": 4096,
      "system": systemPrompt,
      "messages": [
        {
          "role": "user",
          "content": userMessage,
        }
      ]
    };
    
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(payload),
    );
    
    if (response.statusCode != 200) {
      throw Exception('LLM API Error: ${response.statusCode} - ${response.body}');
    }
    
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _extractJson(String text) {
    final startIndex = text.indexOf('{');
    final endIndex = text.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
      return text.substring(startIndex, endIndex + 1);
    }
    return text;
  }
}
