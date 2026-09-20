package com.lesgo.saar.automation

import android.view.accessibility.AccessibilityNodeInfo
import com.lesgo.saar.domain.ElementRole

data class SensitiveScreen(val detected: Boolean, val reason: String = "")

class SensitiveScreenGuard {
    fun inspect(root: AccessibilityNodeInfo?): SensitiveScreen {
        if (root == null) return SensitiveScreen(false)
        val queue = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            when (NodeSemantics.roleOf(node)) {
                ElementRole.PASSWORD_FIELD -> return SensitiveScreen(true, "password or PIN field detected")
                ElementRole.OTP_FIELD -> return SensitiveScreen(true, "OTP verification field detected")
                ElementRole.PAYMENT -> return SensitiveScreen(true, "payment screen detected")
                ElementRole.LOGIN -> return SensitiveScreen(true, "login screen detected")
                ElementRole.CHECKOUT -> return SensitiveScreen(true, "checkout action detected")
                else -> Unit
            }
            repeat(node.childCount) { index -> node.getChild(index)?.let(queue::add) }
        }
        return SensitiveScreen(false)
    }
}
