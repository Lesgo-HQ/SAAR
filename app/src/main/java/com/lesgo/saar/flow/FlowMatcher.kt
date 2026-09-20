package com.lesgo.saar.flow

import com.lesgo.saar.data.SaarRepository
import com.lesgo.saar.domain.FlowDefinition
import com.lesgo.saar.domain.MatchResult
import com.lesgo.saar.domain.VoiceRequest

class FlowMatcher(
    private val repository: SaarRepository,
    private val reasoner: SemanticReasoner
) {
    suspend fun match(request: VoiceRequest, currentPackage: String?): MatchResult {
        val candidates = repository.flows()
            .filter { currentPackage == null || it.appPackage == currentPackage }
            .map { flow -> flow to flow.examples.maxOf { reasoner.similarity(request.intentPhrase, it) } }
            .sortedByDescending { it.second }
        val best = candidates.firstOrNull() ?: return MatchResult.Unknown("I don't have a learned flow for this app yet.")
        val runnerUp = candidates.getOrNull(1)
        if (best.second < MIN_CONFIDENCE) return MatchResult.Unknown("I couldn't confidently match that request to a learned flow.")
        if (runnerUp != null && best.second - runnerUp.second < AMBIGUITY_MARGIN) {
            return MatchResult.Ambiguous(candidates.take(2).map { it.first })
        }
        val slots = reasoner.resolveSlots(best.first, request)
        val missing = best.first.slots.filter { it.required && slots[it.name].isNullOrBlank() }
        if (missing.isNotEmpty()) return MatchResult.Unknown("I need ${missing.joinToString { it.name.replace('_', ' ') }} before I can continue.")
        return MatchResult.Match(best.first, slots, best.second)
    }

    private companion object {
        const val MIN_CONFIDENCE = 0.18f
        const val AMBIGUITY_MARGIN = 0.08f
    }
}
