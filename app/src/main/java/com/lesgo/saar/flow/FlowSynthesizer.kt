package com.lesgo.saar.flow

import com.lesgo.saar.domain.ActionKind
import com.lesgo.saar.domain.CapturedAction
import com.lesgo.saar.domain.ElementRole
import com.lesgo.saar.domain.FlowDefinition
import com.lesgo.saar.domain.FlowStep
import com.lesgo.saar.domain.SlotDefinition

class FlowSynthesizer(private val reasoner: SemanticReasoner) {
    fun synthesize(utterance: String, appPackage: String, rawTrace: List<CapturedAction>): FlowDefinition {
        require(appPackage.isNotBlank()) { "A target app is required to save a flow." }
        val trace = filterIncidentalActions(rawTrace)
        require(trace.isNotEmpty()) { "No usable actions were captured." }
        val slots = inferSlots(utterance, trace)
        val steps = trace.mapIndexedNotNull { index, action ->
            val role = action.node?.role ?: return@mapIndexedNotNull null
            val slot = slotFor(action, slots)
            FlowStep(index + 1, action.kind, role, slot, action.node.siblingRoles)
        }
        return FlowDefinition(
            appPackage = appPackage,
            triggerIntent = reasoner.intentName(utterance),
            examples = listOf(utterance),
            slots = slots,
            steps = steps
        )
    }

    private fun filterIncidentalActions(trace: List<CapturedAction>): List<CapturedAction> = trace
        .filter { action -> action.node != null && action.kind != ActionKind.BACK }
        .filterNot { it.node?.role == ElementRole.UNKNOWN && it.kind != ActionKind.SCROLL_FORWARD }
        .fold(mutableListOf()) { kept, action ->
            val duplicate = kept.lastOrNull()?.let { last ->
                last.kind == action.kind && last.node?.role == action.node?.role && action.atMillis - last.atMillis < 250
            } ?: false
            if (!duplicate) kept += action
            kept
        }

    private fun inferSlots(utterance: String, trace: List<CapturedAction>): List<SlotDefinition> {
        val slots = mutableListOf<SlotDefinition>()
        trace.firstOrNull { it.kind == ActionKind.TYPE && it.text?.isNotBlank() == true }?.let { typed ->
            if (typed.node?.role in setOf(ElementRole.SEARCH_FIELD, ElementRole.TEXT_FIELD)) {
                slots += SlotDefinition("item", "string", typed.text?.trim(), required = true)
            }
        }
        if (trace.any { it.node?.role == ElementRole.QUANTITY_CONTROL }) slots += SlotDefinition("quantity", "int", "1")
        if (trace.any { it.node?.role == ElementRole.ADDRESS_SELECTOR }) {
            val address = Regex("\\b(home|work)\\b", RegexOption.IGNORE_CASE).find(utterance)?.value?.replaceFirstChar(Char::uppercase)
            slots += SlotDefinition("address_label", "string", address, required = true)
        }
        return slots.distinctBy { it.name }
    }

    private fun slotFor(action: CapturedAction, slots: List<SlotDefinition>): String? = when {
        action.kind == ActionKind.TYPE && action.node?.role in setOf(ElementRole.SEARCH_FIELD, ElementRole.TEXT_FIELD) -> slots.firstOrNull { it.name == "item" }?.name
        action.node?.role == ElementRole.QUANTITY_CONTROL -> slots.firstOrNull { it.name == "quantity" }?.name
        action.node?.role == ElementRole.ADDRESS_SELECTOR -> slots.firstOrNull { it.name == "address_label" }?.name
        else -> null
    }
}
