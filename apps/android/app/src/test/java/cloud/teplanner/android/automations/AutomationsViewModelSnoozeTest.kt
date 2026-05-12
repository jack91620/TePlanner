package cloud.teplanner.android.automations

import cloud.teplanner.android.core.network.AutomationsApi
import cloud.teplanner.android.core.network.BaseResponse
import cloud.teplanner.android.core.network.CapabilityListResponse
import cloud.teplanner.android.core.network.RecentFiresResponse
import cloud.teplanner.android.core.network.ReorderRequest
import cloud.teplanner.android.core.network.RuleCreateRequest
import cloud.teplanner.android.core.network.RuleListResponse
import cloud.teplanner.android.core.network.RuleResponse
import cloud.teplanner.android.core.network.RuleUpdateRequest
import cloud.teplanner.android.core.network.SnoozeListResponse
import cloud.teplanner.android.core.network.SnoozeRecord
import cloud.teplanner.android.core.network.SnoozeRequest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.JsonObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AutomationsViewModelSnoozeTest {

    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /** unsnoozeAll iterates over every snoozed rule + calls
     *  DELETE /automations/{id}/snooze for each. After completion the
     *  in-memory snooze map is empty. Mirrors the iOS
     *  AutomationRulesStore.unsnoozeAll behavior. */
    @Test
    fun `unsnoozeAll clears every snoozed rule via API`() = runTest(dispatcher) {
        val rules = listOf(rule("a"), rule("b"), rule("c"))
        val snoozes = mapOf(
            "a" to snoozeRecord("a"),
            "b" to snoozeRecord("b"),
        )
        val api = RecordingApi(initialRules = rules, initialSnoozes = snoozes)
        val vm = AutomationsViewModel(api)
        advanceUntilIdle()  // init refresh

        assertEquals(2, vm.state.value.snoozes.size)

        vm.unsnoozeAll()
        advanceUntilIdle()

        assertEquals(setOf("a", "b"), api.unsnoozedIds)
        assertTrue("snoozes map cleared", vm.state.value.snoozes.isEmpty())
    }

    /** Calling unsnoozeAll on an empty snooze map is a no-op. */
    @Test
    fun `unsnoozeAll with no snoozes does nothing`() = runTest(dispatcher) {
        val api = RecordingApi(initialRules = listOf(rule("a")), initialSnoozes = emptyMap())
        val vm = AutomationsViewModel(api)
        advanceUntilIdle()

        vm.unsnoozeAll()
        advanceUntilIdle()

        assertTrue("no API calls made", api.unsnoozedIds.isEmpty())
    }

    /** Per-rule snooze via VM goes through `POST /automations/{id}/snooze`
     *  and surfaces as a new entry in the snoozes map. Banner-driving
     *  state changes correctly. */
    @Test
    fun `snooze inserts record into state on success`() = runTest(dispatcher) {
        val api = RecordingApi(initialRules = listOf(rule("a")), initialSnoozes = emptyMap())
        val vm = AutomationsViewModel(api)
        advanceUntilIdle()

        vm.snooze("a", 1.0)
        advanceUntilIdle()

        assertEquals(setOf("a"), vm.state.value.snoozes.keys)
        assertEquals(listOf("a" to 1.0), api.snoozedCalls)
    }

    private fun rule(id: String) = RuleResponse(
        id = id,
        name = "rule-$id",
        spec = JsonObject(emptyMap()),
        enabled = true,
    )

    private fun snoozeRecord(ruleId: String) = SnoozeRecord(
        ruleId = ruleId,
        snoozedUntilUtc = "2026-05-13T01:00:00Z",
        reason = null,
        createdAt = "2026-05-13T00:00:00Z",
    )

    private class RecordingApi(
        private var initialRules: List<RuleResponse>,
        private var initialSnoozes: Map<String, SnoozeRecord>,
    ) : AutomationsApi {

        val unsnoozedIds = mutableSetOf<String>()
        val snoozedCalls = mutableListOf<Pair<String, Double>>()

        override suspend fun list(): RuleListResponse =
            RuleListResponse(rules = initialRules)

        override suspend fun create(body: RuleCreateRequest): RuleResponse {
            error("not used")
        }

        override suspend fun update(id: String, body: RuleUpdateRequest): RuleResponse {
            error("not used")
        }

        override suspend fun delete(id: String): BaseResponse = BaseResponse(success = true)

        override suspend fun listSnoozes(): SnoozeListResponse =
            SnoozeListResponse(snoozes = initialSnoozes.values.toList())

        override suspend fun snooze(id: String, body: SnoozeRequest): SnoozeRecord {
            snoozedCalls.add(id to (body.hours ?: 0.0))
            val rec = SnoozeRecord(
                ruleId = id,
                snoozedUntilUtc = "2026-05-13T01:00:00Z",
                reason = body.reason,
                createdAt = "2026-05-13T00:00:00Z",
            )
            initialSnoozes = initialSnoozes + (id to rec)
            return rec
        }

        override suspend fun unsnooze(id: String): BaseResponse {
            unsnoozedIds.add(id)
            initialSnoozes = initialSnoozes - id
            return BaseResponse(success = true)
        }

        override suspend fun reorder(body: ReorderRequest): RuleListResponse =
            RuleListResponse(rules = initialRules)

        override suspend fun recentFires(limit: Int): RecentFiresResponse =
            RecentFiresResponse(fires = emptyList())

        override suspend fun capabilities(): CapabilityListResponse =
            CapabilityListResponse(capabilities = emptyList())
    }
}
