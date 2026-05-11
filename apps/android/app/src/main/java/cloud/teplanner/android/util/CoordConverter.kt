package cloud.teplanner.android.util

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * WGS-84 ↔ GCJ-02 conversion (China "Mars coordinates" offset).
 * Direct port of iOS CoordConverter (Utilities/CoordConverter.swift).
 *
 * Convention:
 *   - Backend + Tesla telemetry + Android in-memory data: WGS-84.
 *   - AMap (MapView, POI responses): GCJ-02.
 *   - Convert at the boundary only.
 *
 * Off-mainland (loose bbox) inputs are passed through unchanged so
 * overseas Teslas stay on the map.
 */
object CoordConverter {
    private const val A: Double = 6_378_245.0
    private const val EE: Double = 0.006_693_421_622_965_943_23

    data class LatLng(val lat: Double, val lng: Double)

    fun wgs84ToGcj02(p: LatLng): LatLng {
        if (!isInChina(p)) return p
        val dLat = transformLat(p.lng - 105.0, p.lat - 35.0)
        val dLng = transformLng(p.lng - 105.0, p.lat - 35.0)
        val radLat = p.lat / 180.0 * PI
        var magic = sin(radLat)
        magic = 1 - EE * magic * magic
        val sqrtMagic = sqrt(magic)
        val dLatFinal = (dLat * 180.0) / ((A * (1 - EE)) / (magic * sqrtMagic) * PI)
        val dLngFinal = (dLng * 180.0) / (A / sqrtMagic * cos(radLat) * PI)
        return LatLng(p.lat + dLatFinal, p.lng + dLngFinal)
    }

    fun gcj02ToWgs84(p: LatLng): LatLng {
        if (!isInChina(p)) return p
        var guess = p
        repeat(3) {
            val forward = wgs84ToGcj02(guess)
            val dLat = forward.lat - guess.lat
            val dLng = forward.lng - guess.lng
            guess = LatLng(p.lat - dLat, p.lng - dLng)
        }
        return guess
    }

    private fun isInChina(p: LatLng): Boolean {
        return p.lng in 72.004..137.8347 && p.lat in 0.8293..55.8271
    }

    private fun transformLat(x: Double, y: Double): Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y +
                  0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * PI) + 20.0 * sin(2.0 * x * PI)) * 2.0 / 3.0
        ret += (20.0 * sin(y * PI) + 40.0 * sin(y / 3.0 * PI)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * PI) + 320.0 * sin(y * PI / 30.0)) * 2.0 / 3.0
        return ret
    }

    private fun transformLng(x: Double, y: Double): Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x +
                  0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * PI) + 20.0 * sin(2.0 * x * PI)) * 2.0 / 3.0
        ret += (20.0 * sin(x * PI) + 40.0 * sin(x / 3.0 * PI)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * PI) + 300.0 * sin(x / 30.0 * PI)) * 2.0 / 3.0
        return ret
    }
}
