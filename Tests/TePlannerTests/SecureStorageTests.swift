import XCTest
@testable import TePlannerKit

final class InMemorySecureStorageTests: XCTestCase {
    func testStoresAndRetrievesValue() {
        let storage = InMemorySecureStorage()
        storage.authToken = "abc.def"
        XCTAssertEqual(storage.authToken, "abc.def")
    }

    func testNilClearsValue() {
        let storage = InMemorySecureStorage()
        storage.userId = "42"
        XCTAssertEqual(storage.userId, "42")
        storage.userId = nil
        XCTAssertNil(storage.userId)
    }

    func testRemoveAllClearsEverything() {
        let storage = InMemorySecureStorage()
        storage.authToken = "a"
        storage.refreshToken = "r"
        storage.userId = "u"
        storage.removeAll()
        XCTAssertNil(storage.authToken)
        XCTAssertNil(storage.refreshToken)
        XCTAssertNil(storage.userId)
    }

    func testKeysAreIndependent() {
        let storage = InMemorySecureStorage()
        storage.authToken = "T"
        storage.refreshToken = "R"
        XCTAssertEqual(storage.authToken, "T")
        XCTAssertEqual(storage.refreshToken, "R")
        storage.authToken = nil
        XCTAssertNil(storage.authToken)
        XCTAssertEqual(storage.refreshToken, "R")
    }
}
