package com.lesgo.saar.automation

import android.view.accessibility.AccessibilityNodeInfo
import com.lesgo.saar.domain.ElementRole

object NodeFinder {
    fun find(root: AccessibilityNodeInfo?, role: ElementRole): AccessibilityNodeInfo? {
        if (root == null) return null
        val queue = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        val candidates = mutableListOf<AccessibilityNodeInfo>()
        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            if (NodeSemantics.roleOf(node) == role) candidates += node
            repeat(node.childCount) { index -> node.getChild(index)?.let(queue::add) }
        }
        return candidates.sortedWith(compareByDescending<AccessibilityNodeInfo> { it.isVisibleToUser }.thenByDescending { it.isClickable || it.isEditable }).firstOrNull()
    }
}
