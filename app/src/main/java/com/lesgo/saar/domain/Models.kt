package com.lesgo.saar.domain

import android.graphics.Rect
import java.util.UUID

enum class AutomationMode { IDLE, TEACHING, REPLAYING, PAUSED_SENSITIVE, NEEDS_CLARIFICATION }
enum class ActionKind { TAP, TYPE, SELECT, SCROLL_FORWARD, BACK, STOP_BEFORE }
enum class ElementRole {
    SEARCH_FIELD, RESULT_ITEM, PRIMARY_ACTION, ADD_TO_CART, QUANTITY_CONTROL,
    ADDRESS_SELECTOR, CHECKOUT, LOGIN, PASSWORD_FIELD, OTP_FIELD, PAYMENT,
    DISMISS, NAVIGATION, SCROLL_CONTAINER, TEXT_FIELD, UNKNOWN
}

data class NodeSnapshot(
    val role: ElementRole,
    val className: String,
    val viewId: String?,
    val contentDescription: String?,
    val isEditable: Boolean,
    val isClickable: Boolean,
    val bounds: Rect,
    val siblingRoles: Set<ElementRole> = emptySet()
)

data class CapturedAction(
    val kind: ActionKind,
    val node: NodeSnapshot?,
    val text: String? = null,
    val atMillis: Long = System.currentTimeMillis()
)

data class SlotDefinition(
    val name: String,
    val type: String,
    val defaultValue: String? = null,
    val required: Boolean = false
)

data class FlowStep(
    val id: Int,
    val action: ActionKind,
    val targetRole: ElementRole,
    val valueSlot: String? = null,
    val expectedRoles: Set<ElementRole> = emptySet()
)

data class FlowDefinition(
    val id: String = UUID.randomUUID().toString(),
    val appPackage: String,
    val triggerIntent: String,
    val examples: List<String>,
    val slots: List<SlotDefinition>,
    val steps: List<FlowStep>,
    val createdAt: Long = System.currentTimeMillis()
)

data class VoiceRequest(
    val rawText: String,
    val intentPhrase: String,
    val slots: Map<String, String>,
    val teachRequested: Boolean
)

sealed interface MatchResult {
    data class Match(val flow: FlowDefinition, val slots: Map<String, String>, val confidence: Float) : MatchResult
    data class Ambiguous(val candidates: List<FlowDefinition>) : MatchResult
    data class Unknown(val explanation: String) : MatchResult
}

sealed interface ReplayOutcome {
    data class Completed(val completedSteps: Int) : ReplayOutcome
    data class PausedSensitive(val reason: String) : ReplayOutcome
    data class NeedsClarification(val question: String) : ReplayOutcome
    data class Failed(val reason: String) : ReplayOutcome
}
