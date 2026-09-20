package com.lesgo.saar.flow

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalSemanticReasonerTest {
    private val reasoner = LocalSemanticReasoner()

    @Test fun `extracts quantity and address from a command`() {
        val request = reasoner.parseRequest("Order 2 garlic breads for home")

        assertEquals("2", request.slots["quantity"])
        assertEquals("Home", request.slots["address_label"])
    }

    @Test fun `scores related requests higher than unrelated requests`() {
        val related = reasoner.similarity("order pizza from dominos", "order margherita pizza from dominos")
        val unrelated = reasoner.similarity("order pizza from dominos", "buy headphones on amazon")

        assertTrue(related > unrelated)
    }
}
