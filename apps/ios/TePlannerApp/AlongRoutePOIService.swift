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
/// **并行**发出（一条 1000km 路线串行要 20+ 次往返；并行下来一两秒
/// 全部回来）。每段加超时（15s），一段卡住不会拖垮整条路线。
@MainActor
final class AlongRoutePOIService: NSObject, AlongRoutePOIProvider, @unchecked Sendable {
    private let api: AMapSearchAPI
    private var pending: [ObjectIdentifier: PendingChunk] = [:]

    private struct PendingChunk {
        let request: AMapRoutePOISearchRequest
        let cont: CheckedContinuation<[AMapRoutePOI], Error>
    }

    /// 单段最大里程，留 20km 余量到 SDK 70km 上限。
    private let chunkKmLimit: Double = 50

    /// 道路周围搜索范围（米）。SDK 范围 0–500，默认 250；用 500 兜
    /// 高速服务区可能稍微偏离主路的情况。
    private let corridorRange: Int = 500

    /// 单次 chunk SDK 调用的超时时间。一段正常返回应在 1-3s 之内；
    /// 给到 15s 容忍弱网，超过这个时间认为 SDK 卡死了。
    private let chunkTimeout: TimeInterval = 15

    override init() {
        self.api = AMapSearchAPI()
        super.init()
        self.api.delegate = self
    }

    /// 输入一条完整路线的 polyline (Coordinate 数组)，返回沿途所有
    /// 充电站 POI（已去重）。出错时抛出。
    func searchChargingStations(
        polyline: [Coordinate]
    ) async throws -> [AlongRoutePOI] {
        guard !polyline.isEmpty else { return [] }

        let tuples = polyline.map { ($0.latitude, $0.longitude) }
        let chunks = Self.chunk(polyline: tuples, maxKm: chunkKmLimit)
        let started = Date()
        Log.app.notice("alongby: \(chunks.count, privacy: .public) chunks for \(polyline.count, privacy: .public)-pt polyline (parallel)")

        // Fan out all chunks at once. Fail-fast: first error cancels
        // the rest. Any single chunk timing out throws AlongRoutePOIError.timeout.
        let allPOIs = try await withThrowingTaskGroup(of: [AMapRoutePOI].self) { group in
            for (index, chunk) in chunks.enumerated() {
                group.addTask { @MainActor [self] in
                    let chunkStart = Date()
                    do {
                        let result = try await searchOneChunkWithTimeout(chunk: chunk)
                        let ms = Int(Date().timeIntervalSince(chunkStart) * 1000)
                        Log.app.debug("alongby chunk \(index, privacy: .public) ok: \(result.count, privacy: .public) POIs in \(ms, privacy: .public)ms")
                        return result
                    } catch {
                        let ms = Int(Date().timeIntervalSince(chunkStart) * 1000)
                        Log.app.error("alongby chunk \(index, privacy: .public) failed after \(ms, privacy: .public)ms: \(error.localizedDescription, privacy: .public)")
                        throw error
                    }
                }
            }
            var combined: [AMapRoutePOI] = []
            for try await chunkResult in group {
                combined.append(contentsOf: chunkResult)
            }
            return combined
        }

        var seen: [String: AlongRoutePOI] = [:]
        for raw in allPOIs {
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
        let totalMs = Int(Date().timeIntervalSince(started) * 1000)
        Log.app.notice("alongby: \(chunks.count, privacy: .public) chunks → \(seen.count, privacy: .public) unique POIs in \(totalMs, privacy: .public)ms total")
        return Array(seen.values)
    }

    /// SDK call wrapped with a hard timeout. If the SDK doesn't call
    /// back within `chunkTimeout`, we resume the continuation with a
    /// timeout error and forget the request so a late callback is a no-op.
    private func searchOneChunkWithTimeout(
        chunk: [(Double, Double)]
    ) async throws -> [AMapRoutePOI] {
        let request = AMapRoutePOISearchRequest()
        request.searchType = .chargingPile
        request.range = corridorRange
        request.polyline = chunk.map {
            AMapGeoPoint.location(withLatitude: CGFloat($0.0), longitude: CGFloat($0.1))
        }
        let key = ObjectIdentifier(request)

        let timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(chunkTimeout * 1_000_000_000))
            guard let self else { return }
            if let entry = self.pending.removeValue(forKey: key) {
                entry.cont.resume(throwing: AlongRoutePOIError.timeout)
            }
        }

        do {
            let result = try await withCheckedThrowingContinuation { cont in
                pending[key] = PendingChunk(request: request, cont: cont)
                api.aMapRoutePOISearch(request)
            }
            timeoutTask.cancel()
            return result
        } catch {
            timeoutTask.cancel()
            throw error
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
            guard let entry = pending.removeValue(forKey: key) else { return }
            entry.cont.resume(returning: response?.pois ?? [])
        }
    }

    nonisolated func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        // SDK 把所有 search request 混在一个 delegate 里——只 resume
        // 我们认得的 RoutePOI 请求。
        guard let req = request as? AMapRoutePOISearchRequest else { return }
        let key = ObjectIdentifier(req)
        Task { @MainActor in
            guard let entry = pending.removeValue(forKey: key) else { return }
            entry.cont.resume(throwing: error ?? AlongRoutePOIError.unknown)
        }
    }
}

enum AlongRoutePOIError: LocalizedError {
    case unknown
    case timeout

    var errorDescription: String? {
        switch self {
        case .unknown: return "未知错误"
        case .timeout: return "沿途搜索超时"
        }
    }
}
