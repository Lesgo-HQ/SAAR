package com.lesgo.saar.flow

import com.lesgo.saar.domain.ElementRole
import com.lesgo.saar.domain.FlowDefinition
import com.lesgo.saar.domain.VoiceRequest
import kotlin.math.max

interface SemanticReasoner {
    fun parseRequest(transcript: String): VoiceRequest
    fun intentName(utterance: String): String
    fun similarity(left: String, right: String): Float
    fun resolveSlots(flow: FlowDefinition, request: VoiceRequest): Map<String, String>
}

/** Offline deterministic fallback. A hosted semantic provider can implement this interface without touching replay code. */
class LocalSemanticReasoner : SemanticReasoner {
    override fun parseRequest(transcript: String): VoiceRequest {
        val normalized = transcript.trim().replace(Regex("\\s+"), " ")
        val lower = normalized.lowercase()
        val teaching = Regex("^(teach|learn|record|show)\\b").containsMatchIn(lower)
        val intent = normalized.replace(Regex("^(teach|learn|record|show)( me)?( how to)?\\s+", RegexOption.IGNORE_CASE), "")
        val slots = linkedMapOf<String, String>()
        Regex("\\b(\\d+)\\s+(?:x\\s*)?([\\p{L}][\\p{L}\\s-]{1,40})", RegexOption.IGNORE_CASE).find(lower)?.let {
            slots["quantity"] = it.groupValues[1]
        }
        Regex("\\b(home|work)\\b", RegexOption.IGNORE_CASE).find(normalized)?.let { slots["address_label"] = it.value.replaceFirstChar(Char::uppercase) }
        return VoiceRequest(normalized, intent.ifBlank { normalized }, slots, teaching)
    }

    override fun intentName(utterance: String): String = tokenize(utterance)
        .filterNot { it in stopWords || it.matches(Regex("\\d+")) }
        .take(4)
        .joinToString("_")
        .ifBlank { "user_task" }

    override fun similarity(left: String, right: String): Float {
        val a = tokenize(left).filterNot { it in stopWords }.toSet()
        val b = tokenize(right).filterNot { it in stopWords }.toSet()
        if (a.isEmpty() || b.isEmpty()) return 0f
        return a.intersect(b).size.toFloat() / max(1, a.union(b).size).toFloat()
    }

    override fun resolveSlots(flow: FlowDefinition, request: VoiceRequest): Map<String, String> {
        val resolved = flow.slots.mapNotNull { slot -> slot.defaultValue?.let { slot.name to it } }.toMap().toMutableMap()
        resolved.putAll(request.slots)
        flow.slots.filter { it.name == "item" }.forEach { slot ->
            val previous = slot.defaultValue.orEmpty()
            val candidate = replaceKnownPhrase(request.intentPhrase, flow.examples.firstOrNull().orEmpty(), previous)
            if (candidate.isNotBlank()) resolved[slot.name] = candidate
        }
        return resolved
    }

    private fun replaceKnownPhrase(command: String, example: String, defaultValue: String): String {
        if (defaultValue.isBlank()) return ""
        val defaultPattern = Regex("\\b${Regex.escape(defaultValue)}\\b", RegexOption.IGNORE_CASE)
        if (defaultPattern.containsMatchIn(command)) return defaultValue
        val anchors = listOf("order", "buy", "search for", "find", "get", "add")
        anchors.firstNotNullOfOrNull { anchor ->
            Regex("\\b$anchor\\s+(.+?)(?:\\s+(?:from|on|at|to|for)\\b|$)", RegexOption.IGNORE_CASE)
                .find(command)?.groupValues?.getOrNull(1)?.trim()
        }?.let { return it.replace(Regex("^\\d+\\s+(?:x\\s*)?"), "").trim() }
        val commandWords = tokenize(command).filterNot { it in tokenize(example) || it in stopWords || it.matches(Regex("\\d+")) }
        return commandWords.joinToString(" ").ifBlank { defaultValue }
    }

    private fun tokenize(value: String) = value.lowercase().split(Regex("[^\\p{L}\\p{N}]+")) .filter { it.isNotBlank() }

    private companion object {
        val stopWords = setOf("a", "an", "the", "to", "from", "on", "at", "in", "my", "me", "please", "some", "of", "and", "with", "for", "how")
    }
}

fun ElementRole.isSensitive() = this in setOf(ElementRole.LOGIN, ElementRole.PASSWORD_FIELD, ElementRole.OTP_FIELD, ElementRole.PAYMENT, ElementRole.CHECKOUT)
