import Foundation
import AMapSearchKit
import TePlannerKit

/// AMap iOS SDK 沿途 POI 搜索的 async/await 包装。
///
/// 为什么不用后端 Web Service：AMap Web 没有真正的"沿路线走廊"接口
/// （`/v3/route/poiline` 默认 key 不开放），用 `/place/around` 采样
/// 会拿到不在路上的 POI（停车场/小区等）。SDK 的 `AMapRoutePOISearch`
/// 是真正按道路走廊算法返回沿途 POI。
///
/// 关键限制（来自 AMap 头文件）：
/// > 沿途搜索, 注意起点和终点不能相距太远(大概70公里)，否则可能搜
/// > 索结果为空
///
/// 因此对长途路线要分段（~50km / 段，留余量）。每段一次 SDK 调用，
/// 合并去重（POI 用 `uid` 唯一）。
@MainActor
final class AlongRoutePOIService: NSObject {
    private let api: AMapSearchAPI
    private var continuations: [ObjectIdentifier: CheckedContinuation<[AMapRoutePOI], Error>] = [:]

    /// 单段最大里程，留 20km 余量到 SDK 70km 上限。
    private let chunkKmLimit: Double = 50

    /// 道路周围搜索范围（米）。SDK 范围 0–500，默认 250；用 500 兜
    /// 高速服务区可能稍微偏离主路的情况。
    private let corridorRange: Int = 500

    override init() {
        self.api = AMapSearchAPI()
        super.init()
        self.api.delegate = self
    }

    /// 输入一条完整路线的 (lat, lng) polyline，返回沿途所有充电站
    /// POI（已去重）。出错时抛出。
    func searchChargingStations(
        polyline: [(Double, Double)]
    ) async throws -> [AlongRoutePOI] {
        guard !polyline.isEmpty else { return [] }

        let chunks = Self.chunk(polyline: polyline, maxKm: chunkKmLimit)
        Log.app.notice("alongby: \(chunks.count, privacy: .public) chunks for \(polyline.count, privacy: .public)-pt polyline")

        var seen: [String: AlongRoutePOI] = [:]
        for (index, chunk) in chunks.enumerated() {
            // fail-fast: SDK / network errors propagate. Empty per-chunk
            // result lists are kept (a rural segment legitimately has
            // no charging stations and shouldn't fail the route).
            let pois: [AMapRoutePOI]
            do {
                pois = try await searchOneChunk(chunk: chunk)
            } catch {
                Log.app.error("alongby chunk \(index, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
            for raw in pois {
                let uid = raw.uid ?? ""
                guard !uid.isEmpty, seen[uid] == nil else { continue }
                let loc = raw.location
                seen[uid] = AlongRoutePOI(
                    id: uid,
                    name: raw.name ?? "",
                    latitude: Double(loc?.latitude ?? 0),
                    longitude: Double(loc?.longitude ?? 0),
                    routeDistanceMeters: raw.distance
                )
            }
        }
        return Array(seen.values)
    }

    private func searchOneChunk(
        chunk: [(Double, Double)]
    ) async throws -> [AMapRoutePOI] {
        let request = AMapRoutePOISearchRequest()
        request.searchType = .chargingPile
        request.range = corridorRange
        request.polyline = chunk.map {
            AMapGeoPoint.location(withLatitude: CGFloat($0.0), longitude: CGFloat($0.1))
        }

        return try await withCheckedThrowingContinuation { cont in
            let key = ObjectIdentifier(request)
            continuations[key] = cont
            api.aMapRoutePOISearch(request)
        }
    }

    /// Walk the polyline accumulating segment distances; close a
    /// chunk once it reaches `maxKm`. Each new chunk starts with the
    /// last point of the previous one so coverage doesn't gap.
    static func chunk(
        polyline: [(Double, Double)],
        maxKm: Double
    ) -> [[(Double, Double)]] {
        guard polyline.count > 1 else { return [polyline] }
        var chunks: [[(Double, Double)]] = []
        var current: [(Double, Double)] = [polyline[0]]
        var carryKm = 0.0
        for i in 1..<polyline.count {
            let prev = polyline[i - 1]
            let cur = polyline[i]
            carryKm += haversineKm(lat1: prev.0, lng1: prev.1, lat2: cur.0, lng2: cur.1)
            current.append(cur)
            // SDK 上限 100 点 / 段，安全限到 95
            if carryKm >= maxKm || current.count >= 95 {
                chunks.append(current)
                current = [cur]
                carryKm = 0
            }
        }
        if current.count >= 2 {
            chunks.append(current)
        }
        return chunks
    }

    private static func haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6371.0
        let dlat = (lat2 - lat1) * .pi / 180
        let dlng = (lng2 - lng1) * .pi / 180
        let a = sin(dlat / 2) * sin(dlat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dlng / 2) * sin(dlng / 2)
        return 2 * R * asin(min(1, sqrt(a)))
    }
}

// MARK: - AMapSearchDelegate

extension AlongRoutePOIService: AMapSearchDelegate {
    nonisolated func onRoutePOISearchDone(
        _ request: AMapRoutePOISearchRequest!,
        response: AMapRoutePOISearchResponse!
    ) {
        guard let request = request else { return }
        let key = ObjectIdentifier(request)
        Task { @MainActor in
            guard let cont = continuations.removeValue(forKey: key) else { return }
            cont.resume(returning: response?.pois ?? [])
        }
    }

    nonisolated func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        // SDK 把所有 search request 混在一个 delegate 里——只 resume
        // 我们认得的 RoutePOI 请求。
        guard let req = request as? AMapRoutePOISearchRequest else { return }
        let key = ObjectIdentifier(req)
        Task { @MainActor in
            guard let cont = continuations.removeValue(forKey: key) else { return }
            cont.resume(throwing: error ?? AlongRoutePOIError.unknown)
        }
    }
}

enum AlongRoutePOIError: Error {
    case unknown
}

/// Decoupled-from-SDK POI shape we hand to the rest of the app.
struct AlongRoutePOI: Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    /// 用户起点经过该 POI 再到终点的累计米数。SDK 内部按路线投影
    /// 计算，比直线距离更接近实际驾驶距离。可能为 0（SDK 未返回）。
    let routeDistanceMeters: Int
}
