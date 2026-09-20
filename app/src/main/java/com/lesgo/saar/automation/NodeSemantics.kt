package com.lesgo.saar.automation

import android.text.InputType
import android.view.accessibility.AccessibilityNodeInfo
import com.lesgo.saar.domain.ElementRole
import com.lesgo.saar.domain.NodeSnapshot

object NodeSemantics {
    fun snapshot(node: AccessibilityNodeInfo): NodeSnapshot = NodeSnapshot(
        role = roleOf(node),
        className = node.className?.toString().orEmpty(),
        viewId = node.viewIdResourceName,
        contentDescription = node.contentDescription?.toString(),
        isEditable = node.isEditable,
        isClickable = node.isClickable,
        bounds = android.graphics.Rect().also(node::getBoundsInScreen),
        siblingRoles = siblingRoles(node)
    )

    fun roleOf(node: AccessibilityNodeInfo): ElementRole {
        val hint = listOfNotNull(node.viewIdResourceName, node.contentDescription?.toString(), node.hintText?.toString(), node.text?.toString())
            .joinToString(" ").lowercase()
        val className = node.className?.toString().orEmpty().lowercase()
        return when {
            isPassword(node) -> ElementRole.PASSWORD_FIELD
            looksLikeOtp(hint) -> ElementRole.OTP_FIELD
            containsAny(hint, "payment", "card number", "upi", "cvv", "pay now", "pay ") -> ElementRole.PAYMENT
            containsAny(hint, "sign in", "log in", "login", "continue with") -> ElementRole.LOGIN
            containsAny(hint, "checkout", "place order") -> ElementRole.CHECKOUT
            node.isEditable && containsAny(hint, "search", "find", "product") -> ElementRole.SEARCH_FIELD
            node.isEditable || className.contains("edittext") -> ElementRole.TEXT_FIELD
            containsAny(hint, "add to cart", "add bag", "add to basket") -> ElementRole.ADD_TO_CART
            containsAny(hint, "quantity", "increase", "decrease", "plus", "minus") -> ElementRole.QUANTITY_CONTROL
            containsAny(hint, "address", "deliver to", "location") -> ElementRole.ADDRESS_SELECTOR
            containsAny(hint, "dismiss", "close", "not now", "skip", "got it") -> ElementRole.DISMISS
            containsAny(hint, "back", "menu", "home", "account", "profile") -> ElementRole.NAVIGATION
            node.isScrollable -> ElementRole.SCROLL_CONTAINER
            node.isClickable && containsAny(hint, "result", "item", "product") -> ElementRole.RESULT_ITEM
            node.isClickable -> ElementRole.PRIMARY_ACTION
            else -> ElementRole.UNKNOWN
        }
    }

    fun isPassword(node: AccessibilityNodeInfo): Boolean {
        val type = node.inputType
        val passwordVariation = type and InputType.TYPE_TEXT_VARIATION_PASSWORD == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
            type and InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
            type and InputType.TYPE_NUMBER_VARIATION_PASSWORD == InputType.TYPE_NUMBER_VARIATION_PASSWORD
        val hint = listOfNotNull(node.viewIdResourceName, node.hintText?.toString(), node.contentDescription?.toString()).joinToString(" ").lowercase()
        return passwordVariation || containsAny(hint, "password", "passcode", "pin")
    }

    private fun siblingRoles(node: AccessibilityNodeInfo): Set<ElementRole> {
        val parent = node.parent ?: return emptySet()
        return (0 until parent.childCount).mapNotNull { parent.getChild(it)?.let(::roleOf) }.filter { it != ElementRole.UNKNOWN }.toSet()
    }

    private fun looksLikeOtp(value: String) = containsAny(value, "otp", "one time", "verification code", "verification otp")
    private fun containsAny(value: String, vararg terms: String) = terms.any(value::contains)
}
