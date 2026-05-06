import XCTest
@testable import TePlannerKit

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testIdleStateOnInit() {
        let vm = SearchViewModel(service: MockPOISearchService())
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.query, "")
    }

    func testEmptyQueryStaysIdle() async {
        let vm = SearchViewModel(service: MockPOISearchService(), debounceMillis: 10)
        vm.updateQuery("   ")
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.state, .idle)
    }

    func testDebouncedSearchProducesResults() async {
        let mock = MockPOISearchService(results: [
            .init(id: "1", name: "上海虹桥火车站", address: "申虹路", latitude: 31.19, longitude: 121.32),
            .init(id: "2", name: "上海虹桥机场", address: "迎宾大道", latitude: 31.20, longitude: 121.34),
        ])
        let vm = SearchViewModel(service: mock, debounceMillis: 10)
        vm.updateQuery("虹桥")
        try? await Task.sleep(nanoseconds: 60_000_000)

        if case .results(let pois) = vm.state {
            XCTAssertEqual(pois.count, 2)
            XCTAssertEqual(pois.first?.name, "上海虹桥火车站")
        } else {
            XCTFail("expected .results, got \(vm.state)")
        }
        XCTAssertEqual(mock.callCount, 1)
    }

    func testEmptyResultsMapToEmptyState() async {
        let vm = SearchViewModel(service: MockPOISearchService(results: []), debounceMillis: 10)
        vm.updateQuery("zzznone")
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.state, .empty)
    }

    func testSdkErrorMapsToErrorState() async {
        let vm = SearchViewModel(
            service: MockPOISearchService(error: .sdkError(code: 1004, message: "no network")),
            debounceMillis: 10
        )
        vm.updateQuery("anything")
        try? await Task.sleep(nanoseconds: 50_000_000)
        if case .error(let msg) = vm.state {
            XCTAssertTrue(msg.contains("1004"))
        } else {
            XCTFail("expected .error, got \(vm.state)")
        }
    }

    func testRapidQueriesDebounceToSingleSearch() async {
        let mock = MockPOISearchService(
            results: [.init(id: "1", name: "x", address: "", latitude: 0, longitude: 0)],
            delayNanoseconds: 0
        )
        let vm = SearchViewModel(service: mock, debounceMillis: 50)
        vm.updateQuery("a")
        vm.updateQuery("ab")
        vm.updateQuery("abc")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(mock.callCount, 1, "debounce should collapse three keystrokes")
        XCTAssertEqual(mock.lastKeyword, "abc")
    }

    func testClearResetsState() async {
        let vm = SearchViewModel(
            service: MockPOISearchService(results: [.init(id: "1", name: "x", address: "", latitude: 0, longitude: 0)]),
            debounceMillis: 10
        )
        vm.updateQuery("x")
        try? await Task.sleep(nanoseconds: 50_000_000)
        vm.clear()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.query, "")
    }

    func testSearchNowSkipsDebounce() async {
        let mock = MockPOISearchService(
            results: [.init(id: "1", name: "x", address: "", latitude: 0, longitude: 0)]
        )
        let vm = SearchViewModel(service: mock, debounceMillis: 5_000)
        vm.updateQuery("xxx")
        vm.searchNow()
        try? await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(mock.callCount, 1, "searchNow should fire immediately, ignoring the long debounce")
    }
}

// MARK: - Mock

private final class MockPOISearchService: POISearchService, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastKeyword: String?
    private let results: [POIResult]
    private let error: POISearchError?
    private let delayNanoseconds: UInt64

    init(results: [POIResult] = [], error: POISearchError? = nil, delayNanoseconds: UInt64 = 0) {
        self.results = results
        self.error = error
        self.delayNanoseconds = delayNanoseconds
    }

    func searchByKeyword(_ keyword: String, city: String) async -> Result<[POIResult], POISearchError> {
        callCount += 1
        lastKeyword = keyword
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let error { return .failure(error) }
        return .success(results)
    }

    func searchAround(keyword: String, latitude: Double, longitude: Double, radiusMeters: Int) async -> Result<[POIResult], POISearchError> {
        return .success([])
    }
}
