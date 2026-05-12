package cloud.teplanner.android.hub.quickactions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * Mirror of iOS SemanticIconTests. Pins the 32-entry SF Symbol ↔
 * semantic ID round-trip table so a future addition / typo can't
 * silently misroute shared icons (e.g. a friend on iOS shares
 * "lock" and the Android importer ends up rendering the fallback
 * bolt instead of the lock).
 */
class SemanticIconTest {

    /// Every SF Symbol offered in HubIconLibrary MUST have a semantic
    /// mapping — otherwise sharing an action with that icon would
    /// silently fall back to "bolt" on the receiver.
    @Test
    fun `every picker icon has a semantic ID`() {
        for (sym in HubIconLibrary.all) {
            assertNotNull(
                "Add a semantic ID for SF Symbol '$sym' to SemanticIcon.symbolToSemantic",
                SemanticIcon.symbolToSemantic[sym],
            )
        }
    }

    /// SF Symbol → semantic → SF Symbol must produce the original.
    @Test
    fun `round-trip SF Symbol to semantic and back`() {
        for (sym in HubIconLibrary.all) {
            val sem = SemanticIcon.semanticFor(sym)
            val back = SemanticIcon.symbolFor(sem)
            assertEquals("round-trip broke for $sym → $sem → $back", sym, back)
        }
    }

    @Test
    fun `unknown semantic falls back to bolt fill`() {
        assertEquals("bolt.fill", SemanticIcon.symbolFor("no-such-thing"))
    }

    @Test
    fun `unknown symbol falls back to bolt`() {
        assertEquals("bolt", SemanticIcon.semanticFor("no.such.symbol"))
    }
}
