package com.lesgo.saar.automation

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.lesgo.saar.SaarApplication
import com.lesgo.saar.domain.ActionKind
import com.lesgo.saar.domain.AutomationMode
import com.lesgo.saar.domain.CapturedAction
import com.lesgo.saar.domain.FlowDefinition
import com.lesgo.saar.domain.FlowStep
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class AutomationStatus(val mode: AutomationMode = AutomationMode.IDLE, val message: String = "Ready", val traceCount: Int = 0)

class SaarAccessibilityService : AccessibilityService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val guard = SensitiveScreenGuard()
    private var teaching: TeachingSession? = null
    private var replayJob: Job? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        update(AutomationMode.IDLE, "Accessibility automation is ready")
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        replayJob?.cancel()
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val session = teaching ?: return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == applicationContext.packageName) return
        if (session.appPackage == null && event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) session.appPackage = packageName
        if (session.appPackage != packageName) return
        val source = event.source ?: return
        val action = when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> CapturedAction(ActionKind.TAP, NodeSemantics.snapshot(source))
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> CapturedAction(ActionKind.TYPE, NodeSemantics.snapshot(source), event.text.joinToString(""))
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> CapturedAction(ActionKind.SCROLL_FORWARD, NodeSemantics.snapshot(source))
            else -> null
        } ?: return
        session.trace += action
        update(AutomationMode.TEACHING, "Learning in ${packageName.substringAfterLast('.')}: ${session.trace.size} actions", session.trace.size)
    }

    override fun onInterrupt() = Unit

    fun beginTeaching(utterance: String) {
        if (utterance.isBlank()) {
            update(AutomationMode.NEEDS_CLARIFICATION, "Tell me what task you want to teach first")
            return
        }
        replayJob?.cancel()
        teaching = TeachingSession(utterance)
        update(AutomationMode.TEACHING, "Open the target app and demonstrate the task", 0)
    }

    fun finishTeaching() {
        val session = teaching ?: run { update(AutomationMode.IDLE, "No teaching session is active"); return }
        teaching = null
        val target = session.appPackage
        if (target == null || session.trace.isEmpty()) {
            update(AutomationMode.NEEDS_CLARIFICATION, "I did not capture a usable demonstration. Please try again.")
            return
        }
        scope.launch {
            runCatching { (application as SaarApplication).flowSynthesizer.synthesize(session.utterance, target, session.trace) }
                .onSuccess { flow ->
                    (application as SaarApplication).repository.save(flow)
                    (application as SaarApplication).repository.log(flow.id, "TAUGHT", "Captured ${flow.steps.size} abstract steps")
                    update(AutomationMode.IDLE, "Saved a ${flow.steps.size}-step flow for ${target.substringAfterLast('.')}")
                }
                .onFailure { update(AutomationMode.NEEDS_CLARIFICATION, it.message ?: "Unable to save this demonstration") }
        }
    }

    fun replay(flow: FlowDefinition, slots: Map<String, String>) {
        teaching = null
        replayJob?.cancel()
        replayJob = scope.launch {
            update(AutomationMode.REPLAYING, "Replaying learned flow")
            if (rootInActiveWindow?.packageName?.toString() != flow.appPackage) {
                val launcher = packageManager.getLaunchIntentForPackage(flow.appPackage)
                if (launcher == null) {
                    update(AutomationMode.NEEDS_CLARIFICATION, "I can't open the app this flow was taught in. Please open it and try again.")
                    return@launch
                }
                launcher.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launcher)
                delay(1200)
            }
            var completed = 0
            for (step in flow.steps) {
                val sensitive = guard.inspect(rootInActiveWindow)
                if (sensitive.detected) {
                    (application as SaarApplication).repository.log(flow.id, "PAUSED_SENSITIVE", sensitive.reason)
                    update(AutomationMode.PAUSED_SENSITIVE, "Paused: ${sensitive.reason}. Please complete it yourself.")
                    return@launch
                }
                if (step.action == ActionKind.STOP_BEFORE || step.targetRole in setOf(com.lesgo.saar.domain.ElementRole.PAYMENT, com.lesgo.saar.domain.ElementRole.OTP_FIELD, com.lesgo.saar.domain.ElementRole.PASSWORD_FIELD, com.lesgo.saar.domain.ElementRole.LOGIN)) {
                    update(AutomationMode.PAUSED_SENSITIVE, "Paused before a sensitive step")
                    return@launch
                }
                val target = awaitTarget(step)
                if (target == null) {
                    (application as SaarApplication).repository.log(flow.id, "STUCK", "Missing ${step.targetRole}")
                    update(AutomationMode.NEEDS_CLARIFICATION, "I can't find the expected ${step.targetRole.name.lowercase().replace('_', ' ')}. What should I do?")
                    return@launch
                }
                if (!perform(step, target, slots)) {
                    (application as SaarApplication).repository.log(flow.id, "FAILED", "Could not execute ${step.action}")
                    update(AutomationMode.NEEDS_CLARIFICATION, "That action was unavailable. Please take over or show me the changed screen.")
                    return@launch
                }
                completed++
                update(AutomationMode.REPLAYING, "Completed step $completed of ${flow.steps.size}")
                delay(350)
            }
            (application as SaarApplication).repository.log(flow.id, "COMPLETED", "$completed steps completed")
            update(AutomationMode.IDLE, "Completed $completed steps safely")
        }
    }

    private suspend fun awaitTarget(step: FlowStep): AccessibilityNodeInfo? {
        repeat(12) {
            NodeFinder.find(rootInActiveWindow, step.targetRole)?.let { return it }
            val dismiss = NodeFinder.find(rootInActiveWindow, com.lesgo.saar.domain.ElementRole.DISMISS)
            if (dismiss != null && !guard.inspect(rootInActiveWindow).detected) {
                dismiss.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                update(AutomationMode.REPLAYING, "Dismissed an unexpected interruption")
            }
            delay(500)
        }
        return null
    }

    private fun perform(step: FlowStep, target: AccessibilityNodeInfo, slots: Map<String, String>): Boolean = when (step.action) {
        ActionKind.TYPE -> {
            val value = step.valueSlot?.let(slots::get) ?: return false
            target.performAction(AccessibilityNodeInfo.ACTION_FOCUS) && target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value) })
        }
        ActionKind.SCROLL_FORWARD -> target.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
        ActionKind.BACK -> performGlobalAction(GLOBAL_ACTION_BACK)
        ActionKind.TAP, ActionKind.SELECT -> target.performAction(AccessibilityNodeInfo.ACTION_CLICK) || tapBounds(target)
        ActionKind.STOP_BEFORE -> true
    }

    private fun tapBounds(node: AccessibilityNodeInfo): Boolean {
        val rect = android.graphics.Rect().also(node::getBoundsInScreen)
        if (rect.isEmpty) return false
        val path = Path().apply { moveTo(rect.exactCenterX(), rect.exactCenterY()) }
        val gesture = GestureDescription.Builder().addStroke(GestureDescription.StrokeDescription(path, 0, 80)).build()
        return dispatchGesture(gesture, null, null)
    }

    private fun update(mode: AutomationMode, message: String, traceCount: Int = teaching?.trace?.size ?: 0) {
        _status.value = AutomationStatus(mode, message, traceCount)
    }

    private data class TeachingSession(val utterance: String, var appPackage: String? = null, val trace: MutableList<CapturedAction> = mutableListOf())

    companion object {
        @Volatile private var instance: SaarAccessibilityService? = null
        private val _status = MutableStateFlow(AutomationStatus(message = "Enable accessibility automation to begin"))
        val status: StateFlow<AutomationStatus> = _status
        fun active(): SaarAccessibilityService? = instance
    }
}
