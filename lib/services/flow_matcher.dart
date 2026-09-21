import 'dart:math';
import '../models/flow.dart';
import 'flow_store.dart';
import 'llm_client.dart';

class MatchResult {
  final Flow? flow;
  final double confidence;
  final Map<String, dynamic> resolvedSlots;
  final bool needsClarification;
  final String? clarificationQuestion;

  MatchResult({
    this.flow,
    this.confidence = 0.0,
    this.resolvedSlots = const {},
    this.needsClarification = false,
    this.clarificationQuestion,
  });
}

class FlowMatcher {
  final FlowStore _store;
  final LlmClient _llm;
  static const double _confidenceThreshold = 0.6;
  static const int _topK = 3;

  FlowMatcher(this._store, this._llm);

  /// Match an utterance to a stored flow using embedding similarity + optional LLM re-rank
  Future<MatchResult> match(String utterance, {Map<String, dynamic> extractedSlots = const {}}) async {
    if (_store.embeddings.isEmpty) {
      return MatchResult(
        needsClarification: true,
        clarificationQuestion: "I don't know any flows yet. Would you like to teach me one?",
      );
    }

    // 1. Embed the utterance
    final utteranceEmbedding = await _llm.embed(utterance);

    // 2. Cosine similarity against all stored embeddings
    final List<MapEntry<FlowEmbedding, double>> similarities = _store.embeddings.map((e) {
      return MapEntry(e, _cosineSimilarity(utteranceEmbedding, e.vector));
    }).toList();

    similarities.sort((a, b) => b.value.compareTo(a.value));

    // 3. Take top-k candidates
    final topKEmbeddings = similarities.take(_topK).toList();

    if (topKEmbeddings.isEmpty) {
      return MatchResult(
        needsClarification: true,
        clarificationQuestion: "I couldn't find any matching flows.",
      );
    }

    final bestMatch = topKEmbeddings.first;

    // Retrieve the Flow objects for candidates
    final candidates = <Flow>[];
    for (var em in topKEmbeddings) {
      final f = await _store.getFlow(em.key.flowId);
      if (f != null) candidates.add(f);
    }

    if (candidates.isEmpty) {
      return MatchResult(
        needsClarification: true,
        clarificationQuestion: "I found matching embeddings but no flow data. Database may be corrupted.",
      );
    }

    // 4. If top match confidence > threshold and clearly best, use it directly
    if (bestMatch.value > _confidenceThreshold) {
      bool isAmbiguous = false;
      if (topKEmbeddings.length > 1) {
        final secondBest = topKEmbeddings[1];
        // If top two are very close, it's ambiguous
        if (bestMatch.value - secondBest.value < 0.05) {
          isAmbiguous = true;
        }
      }

      // 5. If multiple close matches, use LLM to re-rank/verify
      if (isAmbiguous && candidates.length > 1) {
        return await _llmRerank(utterance, candidates, extractedSlots);
      } else {
        final flow = candidates.first;
        // 6. Resolve slots
        final resolvedSlots = _resolveSlots(flow, extractedSlots);
        final hasUnresolved = resolvedSlots.values.any((v) => v == null);

        return MatchResult(
          flow: flow,
          confidence: bestMatch.value,
          resolvedSlots: resolvedSlots,
          needsClarification: hasUnresolved,
          clarificationQuestion: hasUnresolved
              ? _buildSlotQuestion(flow, resolvedSlots)
              : null,
        );
      }
    }

    // Below threshold — try LLM re-rank if we have candidates
    if (candidates.isNotEmpty) {
      return await _llmRerank(utterance, candidates, extractedSlots);
    }

    return MatchResult(
      needsClarification: true,
      clarificationQuestion: "I'm not confident about any matching flow. Could you be more specific?",
    );
  }

  /// Cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Resolve extracted slot values against a flow's slot definitions
  Map<String, dynamic> _resolveSlots(Flow flow, Map<String, dynamic> extractedSlots) {
    final Map<String, dynamic> resolved = {};
    for (var slot in flow.slots) {
      if (extractedSlots.containsKey(slot.name)) {
        resolved[slot.name] = extractedSlots[slot.name];
      } else if (slot.defaultValue != null) {
        resolved[slot.name] = slot.defaultValue;
      } else {
        // Mark as unresolved
        resolved[slot.name] = null;
      }
    }
    return resolved;
  }

  /// Build a question about unresolved slots
  String _buildSlotQuestion(Flow flow, Map<String, dynamic> resolvedSlots) {
    final unresolved = resolvedSlots.entries
        .where((e) => e.value == null)
        .map((e) => e.key)
        .toList();
    if (unresolved.length == 1) {
      final slotDef = flow.slots.firstWhere(
        (s) => s.name == unresolved.first,
        orElse: () => flow.slots.first,
      );
      if (slotDef.values != null && slotDef.values!.isNotEmpty) {
        return 'What ${unresolved.first}? Options: ${slotDef.values!.join(', ')}';
      }
      return 'What ${unresolved.first} should I use?';
    }
    return 'I need values for: ${unresolved.join(', ')}. Please specify.';
  }

  /// Use LLM to re-rank candidates and pick the best match
  Future<MatchResult> _llmRerank(
    String utterance,
    List<Flow> candidates,
    Map<String, dynamic> extractedSlots,
  ) async {
    try {
      // Build a prompt for the LLM to pick the best flow
      final candidateDescriptions = candidates.asMap().entries.map((entry) {
        final flow = entry.value;
        return '${entry.key}: "${flow.triggerIntent}" (app: ${flow.appPackage}, '
            'slots: ${flow.slots.map((s) => s.name).join(', ')})';
      }).join('\n');

      final classification = await _llm.classifyIntent(
        '$utterance\n\nAvailable flows:\n$candidateDescriptions\n\nPick the best matching flow index (0-based) or say "none".',
      );

      // Try to extract a flow index from the response
      final taskDesc = classification.taskDescription ?? '';
      Flow bestFlow = candidates.first;

      // Simple heuristic: check if any candidate's trigger_intent is mentioned
      for (final candidate in candidates) {
        if (taskDesc.toLowerCase().contains(candidate.triggerIntent.toLowerCase())) {
          bestFlow = candidate;
          break;
        }
      }

      final resolvedSlots = _resolveSlots(bestFlow, extractedSlots);
      final hasUnresolved = resolvedSlots.values.any((v) => v == null);

      return MatchResult(
        flow: bestFlow,
        confidence: 0.75, // LLM-verified match
        resolvedSlots: resolvedSlots,
        needsClarification: hasUnresolved,
        clarificationQuestion: hasUnresolved
            ? _buildSlotQuestion(bestFlow, resolvedSlots)
            : null,
      );
    } catch (e) {
      // LLM re-rank failed, fall back to first candidate
      final flow = candidates.first;
      final resolvedSlots = _resolveSlots(flow, extractedSlots);
      return MatchResult(
        flow: flow,
        confidence: 0.5,
        resolvedSlots: resolvedSlots,
        needsClarification: true,
        clarificationQuestion: 'I found "${flow.triggerIntent}" but I\'m not fully confident. Should I proceed?',
      );
    }
  }
}
