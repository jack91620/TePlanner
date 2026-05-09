import Foundation
import AMapSearchKit
import TePlannerKit

/// AMap-backed `POISearchService`. Each call spins up a fresh
/// `AMapSearchAPI` + delegate bridge so we don't have to multiplex
/// concurrent requests onto a single delegate. AMap's search SDK is
/// callback-based; we wrap the one-shot delegate response in a
/// `CheckedContinuation` to expose async/await upstream.
final class AMapPOISearchService: POISearchService {
    func searchByKeyword(_ keyword: String, city: String) async -> Result<[POIResult], POISearchError> {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyQuery) }

        return await withCheckedContinuation { continuation in
            let request = AMapPOIKeywordsSearchRequest()
            request.keywords = trimmed
            request.city = city
            request.showFieldsType = .all
            request.cityLimit = false
            request.offset = 20
            request.page = 1
            AMapSearchBridge(continuation: continuation).keywordSearch(request)
        }
    }

    func searchAround(
        keyword: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Int
    ) async -> Result<[POIResult], POISearchError> {
        return await withCheckedContinuation { continuation in
            let request = AMapPOIAroundSearchRequest()
            request.keywords = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            request.location = AMapGeoPoint.location(withLatitude: CGFloat(latitude),
                                                     longitude: CGFloat(longitude))
            request.radius = radiusMeters
            request.showFieldsType = .all
            request.offset = 20
            request.page = 1
            AMapSearchBridge(continuation: continuation).aroundSearch(request)
        }
    }
}

private final class AMapSearchBridge: NSObject, AMapSearchDelegate {
    private let continuation: CheckedContinuation<Result<[POIResult], POISearchError>, Never>
    private let api: AMapSearchAPI?
    // Retain self until the delegate callback fires; AMap holds a weak
    // reference to the delegate.
    private var selfReference: AMapSearchBridge?

    init(continuation: CheckedContinuation<Result<[POIResult], POISearchError>, Never>) {
        self.continuation = continuation
        self.api = AMapSearchAPI()
        super.init()
        self.api?.delegate = self
        self.selfReference = self
    }

    func keywordSearch(_ request: AMapPOIKeywordsSearchRequest) {
        guard let api else {
            finish(.failure(.unknown))
            return
        }
        api.aMapPOIKeywordsSearch(request)
    }

    func aroundSearch(_ request: AMapPOIAroundSearchRequest) {
        guard let api else {
            finish(.failure(.unknown))
            return
        }
        api.aMapPOIAroundSearch(request)
    }

    func onPOISearchDone(_ request: AMapPOISearchBaseRequest!,
                         response: AMapPOISearchResponse!) {
        let pois = response?.pois ?? []
        let mapped = pois.compactMap { poi -> POIResult? in
            guard let location = poi.location else { return nil }
            return POIResult(
                id: poi.uid ?? UUID().uuidString,
                name: poi.name ?? "",
                address: poi.address?.isEmpty == false ? poi.address : (poi.district ?? poi.city ?? ""),
                latitude: Double(location.latitude),
                longitude: Double(location.longitude),
                distance: poi.distance > 0 ? Double(poi.distance) : nil,
                cityName: poi.city
            )
        }
        finish(.success(mapped))
    }

    func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        let nsError = error as NSError?
        finish(.failure(.sdkError(
            code: nsError?.code ?? -1,
            message: nsError?.localizedDescription ?? "AMap search failed"
        )))
    }

    private func finish(_ result: Result<[POIResult], POISearchError>) {
        guard selfReference != nil else { return }
        continuation.resume(returning: result)
        selfReference = nil
    }
}
