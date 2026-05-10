package cloud.teplanner.android.map

import android.content.Context
import android.util.Log
import cloud.teplanner.android.core.network.Coordinate
import cloud.teplanner.android.core.network.POIInput
import com.amap.api.services.core.LatLonPoint
import com.amap.api.services.routepoisearch.RoutePOIItem
import com.amap.api.services.routepoisearch.RoutePOISearch
import com.amap.api.services.routepoisearch.RoutePOISearchQuery
import com.amap.api.services.routepoisearch.RoutePOISearchResult
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Phase F.3.3 — Android port of iOS `AlongRoutePOIService`.
 *
 * AMap Web Service has no road-corridor along-route search; the
 * mobile SDK has `RoutePOISearch` which does. iOS uses
 * `AMapRoutePOISearchRequest`; Android equivalent is
 * `RoutePOISearch` here. We chunk the polyline into ~50km
 * sub-polylines (SDK hint: <70km, 100-pt cap per query) and
 * union the results, keyed by POI id to dedupe.
 *
 * Returns POIInput list ready to POST to /routes/charging-plan.
 */
class AlongRoutePOIService(private val context: Context) {

    suspend fun searchChargingStations(polyline: List<Coordinate>): List<POIInput> {
        if (polyline.size < 2) return emptyList()
        val chunks = chunkPolyline(polyline, MAX_CHUNK_KM)
        val merged = LinkedHashMap<String, POIInput>()
        for (chunk in chunks) {
            val pois = searchChunk(chunk)
            for (p in pois) merged.putIfAbsent(p.id, p)
        }
        Log.i(TAG, "along-route POI search: ${chunks.size} chunks → ${merged.size} unique POIs")
        return merged.values.toList()
    }

    private suspend fun searchChunk(chunk: List<Coordinate>): List<POIInput> {
        if (chunk.size < 2) return emptyList()
        return suspendCancellableCoroutine { cont ->
            val search = RoutePOISearch(context, RoutePOISearchQuery(
                chunk.map { LatLonPoint(it.latitude, it.longitude) },
                RoutePOISearch.RoutePOISearchType.TypeChargeStation,
                CORRIDOR_RADIUS_M,
            ))
            search.setPoiSearchListener(object : RoutePOISearch.OnRoutePOISearchListener {
                override fun onRoutePoiSearched(result: RoutePOISearchResult?, code: Int) {
                    if (code != 1000) {
                        Log.w(TAG, "RoutePOISearch error code=$code")
                        if (cont.isActive) cont.resume(emptyList())
                        return
                    }
                    val items = result?.routePois.orEmpty()
                    val pois = items.map { it.toPOIInput() }
                    if (cont.isActive) cont.resume(pois)
                }
            })
            search.searchRoutePOIAsyn()
        }
    }

    private fun RoutePOIItem.toPOIInput(): POIInput =
        POIInput(
            id = getID() ?: "",
            name = title ?: "未知充电站",
            latitude = point?.latitude ?: 0.0,
            longitude = point?.longitude ?: 0.0,
        )

    private fun chunkPolyline(points: List<Coordinate>, maxKm: Double): List<List<Coordinate>> {
        val chunks = mutableListOf<List<Coordinate>>()
        var current = mutableListOf<Coordinate>()
        var dist = 0.0
        for (i in points.indices) {
            val p = points[i]
            current.add(p)
            if (i > 0) dist += haversineKm(points[i - 1], p)
            if (dist >= maxKm) {
                chunks.add(current.toList())
                current = mutableListOf(p)
                dist = 0.0
            }
        }
        if (current.size >= 2) chunks.add(current.toList())
        return chunks
    }

    private fun haversineKm(a: Coordinate, b: Coordinate): Double {
        val r = 6371.0
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLng = Math.toRadians(b.longitude - a.longitude)
        val sa = Math.sin(dLat / 2)
        val so = Math.sin(dLng / 2)
        val h = sa * sa +
            Math.cos(Math.toRadians(a.latitude)) *
            Math.cos(Math.toRadians(b.latitude)) * so * so
        return 2 * r * Math.asin(Math.min(1.0, Math.sqrt(h)))
    }

    companion object {
        private const val TAG = "AlongRoutePOI"
        private const val MAX_CHUNK_KM = 50.0
        private const val CORRIDOR_RADIUS_M = 5000
    }
}
