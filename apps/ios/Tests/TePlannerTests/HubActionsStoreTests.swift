import XCTest
@testable import TePlannerKit

@MainActor
final class HubActionsStoreTests: XCTestCase {
    private var api: MockAPIService!
    private var store: HubActionsStore!

    override func setUp() async throws {
        api = MockAPIService()
        store = HubActionsStore(apiService: api)
    }

    // MARK: - Seed defaults

    func testLoadOnFreshUserSeedsFourSystemActions() async {
        // Empty bag = brand-new user. Store should populate 4 system
        // actions in row 1 (slots 0..3), leave row 2 empty, and
        // persist back.
        await store.load()

        XCTAssertEqual(store.actions.count, 4)
        XCTAssertTrue(store.actions.allSatisfy(\.isSystem))
        XCTAssertEqual(store.slots.slots.count, 8)
        XCTAssertNotNil(store.slots.slots[0])
        XCTAssertNotNil(store.slots.slots[3])
        XCTAssertNil(store.slots.slots[4])
        // Persisted via PUT (replaceAll=false).
        XCTAssertNotNil(api.lastPutUserSettings)
        XCTAssertFalse(api.lastPutUserSettings!.replaceAll)
        XCTAssertNotNil(api.lastPutUserSettings!.settings["hub.actions"])
        XCTAssertNotNil(api.lastPutUserSettings!.settings["hub.slots"])
    }

    func testLoadOnExistingUserDoesNotReSeed() async {
        // Existing user has hub.* keys (even empty), so we must NOT
        // re-seed defaults — otherwise a user who intentionally
        // cleared all slots would have them reappear every restart.
        api.mockUserSettings = [
            "hub.actions": .array([]),
            "hub.slots": .object([
                "slots": .array([.null, .null, .null, .null,
                                 .null, .null, .null, .null]),
            ]),
        ]
        await store.load()

        XCTAssertEqual(store.actions.count, 0)
        XCTAssertTrue(store.slots.slots.allSatisfy { $0 == nil })
        // No re-seed = no PUT call.
        XCTAssertNil(api.lastPutUserSettings)
    }

    // MARK: - Create / Update / Delete

    func testCreateAddsActionAndFillsFirstEmptySlot() async {
        await store.load()  // seeds 4 defaults in slots 0..3
        let id = await store.create(
            name: "离家模式",
            icon: "house.fill",
            tint: .red,
            steps: [HubActionStep(capability: "tesla.security.door_lock")],
            confirmRequired: false,
        )

        XCTAssertEqual(store.actions.count, 5)
        XCTAssertEqual(store.slots.slots[4], id) // first empty slot
        XCTAssertNil(store.slots.slots[5])
    }

    func testCreateWithoutAssignSlotLeavesSlotsAlone() async {
        await store.load()
        let snapshot = store.slots.slots
        _ = await store.create(
            name: "Pure action",
            icon: "star.fill",
            tint: .green,
            steps: [HubActionStep(capability: "tesla.attention.flash_lights")],
            confirmRequired: false,
            assignToFirstEmpty: false,
        )
        XCTAssertEqual(store.slots.slots, snapshot)
    }

    func testUpdatePreservesIsSystemFlag() async {
        await store.load()
        let lockId = "system_lock"
        // Verify it's actually system before the test.
        XCTAssertEqual(store.action(id: lockId)?.isSystem, true)

        await store.update(
            id: lockId,
            name: "锁",  // shorter
            icon: "lock.fill",
            tint: .gray,  // re-tinted
            steps: [HubActionStep(capability: "tesla.security.door_lock")],
            confirmRequired: true,  // user wants confirmation now
        )

        let updated = store.action(id: lockId)
        XCTAssertEqual(updated?.name, "锁")
        XCTAssertEqual(updated?.tint, .gray)
        XCTAssertEqual(updated?.confirmRequired, true)
        XCTAssertEqual(updated?.isSystem, true)  // ← key invariant
    }

    func testDeleteCustomActionAlsoClearsItsSlot() async {
        await store.load()
        let id = await store.create(
            name: "组合",
            icon: "sparkles",
            tint: .green,
            steps: [HubActionStep(capability: "tesla.security.door_lock")],
            confirmRequired: false,
        )
        XCTAssertEqual(store.slots.slots[4], id)
        XCTAssertEqual(store.actions.count, 5)

        await store.delete(id: id)

        XCTAssertEqual(store.actions.count, 4)
        XCTAssertNil(store.slots.slots[4])
    }

    func testDeleteSystemActionIsNoOp() async {
        // System actions can be re-styled but not deleted — defends
        // against UI accidentally calling delete on a system row.
        await store.load()
        let lockId = "system_lock"
        await store.delete(id: lockId)
        XCTAssertNotNil(store.action(id: lockId))
        XCTAssertEqual(store.actions.count, 4)
    }

    // MARK: - Slot assignment

    func testAssignSlotMovesActionAndClearsOldSlot() async {
        await store.load()
        // 锁车 starts in slot 0. Move it to slot 5.
        let lockId = "system_lock"
        await store.assignSlot(index: 5, actionId: lockId)
        XCTAssertEqual(store.slots.slots[5], lockId)
        XCTAssertNil(store.slots.slots[0])  // ← old slot freed
    }

    func testAssignSlotNilClearsSlot() async {
        await store.load()
        await store.assignSlot(index: 0, actionId: nil)
        XCTAssertNil(store.slots.slots[0])
    }

    func testSwapSlots() async {
        await store.load()
        let before0 = store.slots.slots[0]
        let before3 = store.slots.slots[3]
        await store.swapSlots(0, 3)
        XCTAssertEqual(store.slots.slots[0], before3)
        XCTAssertEqual(store.slots.slots[3], before0)
    }

    // MARK: - Dispatch

    func testRunSingleStepCallsInvokeOnce() async {
        await store.load()
        let result = await store.run(actionId: "system_lock", vehicleId: "V1")
        guard case .success = result else {
            XCTFail("expected success, got \(result)"); return
        }
        XCTAssertEqual(api.invokeCapabilityCallCount, 1)
        XCTAssertEqual(api.invokeCapabilityCalls.first?.capability, "tesla.security.door_lock")
        XCTAssertEqual(api.invokeCapabilityCalls.first?.vehicleId, "V1")
        XCTAssertEqual(store.lastDispatchedActionId, "system_lock")
    }

    func testRunMultiStepCallsInvokeInOrder() async {
        await store.load()
        let macroId = await store.create(
            name: "离家",
            icon: "house.fill",
            tint: .red,
            steps: [
                HubActionStep(capability: "tesla.security.door_lock"),
                HubActionStep(capability: "tesla.climate.stop"),
                HubActionStep(capability: "tesla.security.set_sentry",
                              params: ["on": .bool(true)]),
            ],
            confirmRequired: false,
        )

        let result = await store.run(actionId: macroId, vehicleId: "V42")
        guard case .success = result else {
            XCTFail("expected success, got \(result)"); return
        }
        XCTAssertEqual(api.invokeCapabilityCallCount, 3)
        XCTAssertEqual(api.invokeCapabilityCalls.map(\.capability), [
            "tesla.security.door_lock",
            "tesla.climate.stop",
            "tesla.security.set_sentry",
        ])
        // Param round-trip.
        let lastParams = api.invokeCapabilityCalls.last?.params ?? [:]
        XCTAssertEqual(lastParams["on"], .bool(true))
    }

    func testRunStopsOnFirstStepFailure() async {
        await store.load()
        let macroId = await store.create(
            name: "脏链",
            icon: "sparkles",
            tint: .red,
            steps: [
                HubActionStep(capability: "tesla.security.door_lock"),
                HubActionStep(capability: "tesla.security.set_sentry",
                              params: ["on": .bool(true)]),
            ],
            confirmRequired: false,
        )
        // Fail every invoke. Note: this fails the FIRST step too;
        // we expect the macro to abort right there.
        api.mockInvokeCapabilityResponse = .failure(.serverError(statusCode: 500, message: "boom"))

        let result = await store.run(actionId: macroId, vehicleId: "V42")

        guard case let .failure(.stepFailed(idx, _)) = result else {
            XCTFail("expected stepFailed, got \(result)"); return
        }
        XCTAssertEqual(idx, 0)
        // Only one call → didn't proceed past the failed step.
        XCTAssertEqual(api.invokeCapabilityCallCount, 1)
    }

    func testRunUnknownActionReturnsError() async {
        let result = await store.run(actionId: "does-not-exist", vehicleId: "V1")
        guard case .failure(.unknownAction) = result else {
            XCTFail("expected unknownAction, got \(result)"); return
        }
    }

    // MARK: - JSON round-trip (regression guard for storage format)

    func testActionPoolEncodesAsArrayOfObjects() async {
        await store.load()
        // The bag we PUT should have hub.actions as a JSON array
        // (not e.g. dict-keyed-by-id, which would break Android
        // decoding). Pin the shape.
        guard let bag = api.lastPutUserSettings?.settings,
              case let .array(arr) = bag["hub.actions"] else {
            XCTFail("hub.actions missing or not an array"); return
        }
        XCTAssertEqual(arr.count, 4)
        if case let .object(first) = arr[0] {
            XCTAssertNotNil(first["id"])
            XCTAssertNotNil(first["name"])
            XCTAssertNotNil(first["icon"])
            XCTAssertNotNil(first["steps"])
        } else {
            XCTFail("array element is not an object")
        }
    }

    func testSlotsEncodesAsObjectWithSlotsArray() async {
        await store.load()
        guard let bag = api.lastPutUserSettings?.settings,
              case let .object(obj) = bag["hub.slots"],
              case let .array(slotsArr) = obj["slots"] else {
            XCTFail("hub.slots not in expected shape"); return
        }
        XCTAssertEqual(slotsArr.count, HubSlots.count)
    }
}
