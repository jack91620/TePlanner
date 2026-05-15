package cloud.teplanner.android.hub

import cloud.teplanner.android.core.network.SuggestChargeLimitResponse
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the Hub charge-limit suggestion copy. Cross-platform contract:
 * Android and iOS must produce byte-identical Chinese for the same
 * server response, or users moving between devices see UX skew.
 *
 * Server enums today:
 *   "daily"              — recommend lowering for daily comfort
 *   "upcoming_departure" — recommend raising for an imminent trip
 *   (anything else)      — generic fallback
 */
class ChargeLimitCopyTest {

    @Test fun `daily reason yields lower-then-comfort copy`() {
        val resp = SuggestChargeLimitResponse(
            recommendedPercent = 70, currentPercent = 80,
            reason = "daily", alreadyMatches = false,
        )
        assertEquals("调低充电限额到 70%", chargeLimitTitle(resp))
        assertEquals("当前 80% · 长期日常使用更友好", chargeLimitSubtitle(resp, current = 80))
    }

    @Test fun `upcoming_departure with hoursAway shows countdown`() {
        val resp = SuggestChargeLimitResponse(
            recommendedPercent = 90, currentPercent = 70,
            reason = "upcoming_departure", hoursAway = 3, alreadyMatches = false,
        )
        assertEquals("调高充电限额到 90%", chargeLimitTitle(resp))
        assertEquals("当前 70% · 还有 3 小时出发", chargeLimitSubtitle(resp, current = 70))
    }

    @Test fun `upcoming_departure without hoursAway shows generic note`() {
        val resp = SuggestChargeLimitResponse(
            recommendedPercent = 90, currentPercent = 70,
            reason = "upcoming_departure", hoursAway = null, alreadyMatches = false,
        )
        assertEquals("当前 70% · 即将出行", chargeLimitSubtitle(resp, current = 70))
    }

    @Test fun `upcoming_departure with zero hoursAway shows generic note`() {
        val resp = SuggestChargeLimitResponse(
            recommendedPercent = 90, currentPercent = 70,
            reason = "upcoming_departure", hoursAway = 0, alreadyMatches = false,
        )
        assertEquals("当前 70% · 即将出行", chargeLimitSubtitle(resp, current = 70))
    }

    @Test fun `unknown reason falls back to generic suggestion`() {
        val resp = SuggestChargeLimitResponse(
            recommendedPercent = 80, currentPercent = 70,
            reason = "future_reason_we_dont_know", alreadyMatches = false,
        )
        assertEquals("建议充电限额 80%", chargeLimitTitle(resp))
        assertEquals("当前 70%", chargeLimitSubtitle(resp, current = 70))
    }
}
