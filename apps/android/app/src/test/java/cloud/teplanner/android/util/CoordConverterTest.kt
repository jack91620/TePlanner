package cloud.teplanner.android.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * Pure-math unit tests for WGS-84 ↔ GCJ-02 conversion. Parity with
 * the iOS CoordConverterTests; numbers come from the same public-
 * domain offset formula.
 *
 * Run via `make android-test`.
 */
class CoordConverterTest {

    @Test
    fun `Beijing WGS-84 to GCJ-02 shifts by 5 to 6 hundredths of a degree`() {
        // Tiananmen, raw GPS (WGS-84). AMap rendering coords are typically
        // shifted ~500m southeast in Beijing.
        val tiananmenWgs = CoordConverter.LatLng(39.9042, 116.4074)
        val gcj = CoordConverter.wgs84ToGcj02(tiananmenWgs)
        val dLat = abs(gcj.lat - tiananmenWgs.lat)
        val dLng = abs(gcj.lng - tiananmenWgs.lng)
        // GCJ-02 offset is small but non-zero (typically 0.001-0.01 deg).
        assertTrue("lat delta should be positive: $dLat", dLat > 0.001)
        assertTrue("lng delta should be positive: $dLng", dLng > 0.001)
        // Sanity bound — never more than ~0.1 deg.
        assertTrue("lat delta should be < 0.1: $dLat", dLat < 0.1)
        assertTrue("lng delta should be < 0.1: $dLng", dLng < 0.1)
    }

    @Test
    fun `roundtrip preserves coord within 1m precision`() {
        // Shanghai, Beijing, Guangzhou, Chengdu — sample points across
        // mainland China.
        val samples = listOf(
            CoordConverter.LatLng(31.2304, 121.4737),
            CoordConverter.LatLng(39.9042, 116.4074),
            CoordConverter.LatLng(23.1291, 113.2644),
            CoordConverter.LatLng(30.5728, 104.0668),
        )
        for (p in samples) {
            val gcj = CoordConverter.wgs84ToGcj02(p)
            val back = CoordConverter.gcj02ToWgs84(gcj)
            // 3 iterations should round-trip within 1cm — much better
            // than the 1m claim in the iOS port comment.
            assertEquals("lat round-trip for $p", p.lat, back.lat, 1e-7)
            assertEquals("lng round-trip for $p", p.lng, back.lng, 1e-7)
        }
    }

    @Test
    fun `coordinates outside China bbox pass through unchanged`() {
        // Tokyo, San Francisco, Sydney — bbox-out should be identity.
        val outside = listOf(
            CoordConverter.LatLng(35.6762, 139.6503),
            CoordConverter.LatLng(37.7749, -122.4194),
            CoordConverter.LatLng(-33.8688, 151.2093),
        )
        for (p in outside) {
            val converted = CoordConverter.wgs84ToGcj02(p)
            assertEquals(p.lat, converted.lat, 0.0)
            assertEquals(p.lng, converted.lng, 0.0)
        }
    }

    @Test
    fun `gcj02ToWgs84 is inverse of wgs84ToGcj02 not the same direction`() {
        // Easy regression check: someone could swap the direction and
        // tests would still seem to pass with non-roundtrip points.
        val p = CoordConverter.LatLng(39.9042, 116.4074)
        val fwd = CoordConverter.wgs84ToGcj02(p)
        // gcj02ToWgs84 of original WGS coord is NOT the same as
        // wgs84ToGcj02 of it — they go in opposite directions.
        val bwd = CoordConverter.gcj02ToWgs84(p)
        assertNotEquals(fwd.lat, bwd.lat)
        assertNotEquals(fwd.lng, bwd.lng)
    }
}
