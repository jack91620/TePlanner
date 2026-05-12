package cloud.teplanner.android.map

import cloud.teplanner.android.core.network.ChargingPlanRequest
import cloud.teplanner.android.core.network.ChargingPlanResponse
import cloud.teplanner.android.core.network.PlaceSearchResponse
import cloud.teplanner.android.core.network.RouteOnlyRequest
import cloud.teplanner.android.core.network.RouteOnlyResponse
import cloud.teplanner.android.core.network.RoutePlanListResponse
import cloud.teplanner.android.core.network.RoutePlanLocation
import cloud.teplanner.android.core.network.RoutePlanSummary
import cloud.teplanner.android.core.network.RoutesApi
import cloud.teplanner.android.core.network.SaveRoutePlanRequest
import cloud.teplanner.android.core.network.SaveRoutePlanResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class RecentTripsViewModelTest {

    private val dispatcher = StandardTestDispatcher()

    @Before fun setUp() { Dispatchers.setMain(dispatcher) }
    @After fun tearDown() { Dispatchers.resetMain() }

    @Test
    fun `init loads trips into state`() = runTest(dispatcher) {
        val api = FakeRoutesApi(listOf(
            tripSummary(id = 1, destAddress = "上海火车站"),
            tripSummary(id = 2, destAddress = "杭州东站"),
        ))
        val vm = RecentTripsViewModel(api)
        advanceUntilIdle()

        assertEquals(false, vm.state.value.isLoading)
        assertNull(vm.state.value.error)
        assertEquals(listOf("上海火车站", "杭州东站"),
            vm.state.value.trips.map { it.destination.address })
    }

    @Test
    fun `failed load surfaces error and empty list`() = runTest(dispatcher) {
        val api = FakeRoutesApi(failure = RuntimeException("boom"))
        val vm = RecentTripsViewModel(api)
        advanceUntilIdle()

        assertTrue(vm.state.value.trips.isEmpty())
        assertEquals("boom", vm.state.value.error)
    }

    @Test
    fun `refresh after failure recovers`() = runTest(dispatcher) {
        val api = FakeRoutesApi(failure = RuntimeException("offline"))
        val vm = RecentTripsViewModel(api)
        advanceUntilIdle()
        assertNotNull(vm.state.value.error)

        api.failure = null
        api.trips = listOf(tripSummary(id = 3, destAddress = "黑胖子的家"))
        vm.refresh()
        advanceUntilIdle()

        assertNull(vm.state.value.error)
        assertEquals(1, vm.state.value.trips.size)
    }

    private fun tripSummary(id: Int, destAddress: String) = RoutePlanSummary(
        id = id,
        origin = RoutePlanLocation(lat = 31.23, lng = 121.47, address = "起点"),
        destination = RoutePlanLocation(lat = 31.4, lng = 121.5, address = destAddress),
        totalDistanceKm = 42.0,
        totalDurationMinutes = 90,
        status = "planned",
        createdAt = "2026-05-13T10:00:00+08:00",
    )

    private class FakeRoutesApi(
        var trips: List<RoutePlanSummary> = emptyList(),
        var failure: Throwable? = null,
    ) : RoutesApi {
        override suspend fun route(request: RouteOnlyRequest): RouteOnlyResponse { error("not used") }
        override suspend fun chargingPlan(request: ChargingPlanRequest): ChargingPlanResponse { error("not used") }
        override suspend fun searchPlaces(keyword: String, location: String?): PlaceSearchResponse { error("not used") }
        override suspend fun saveRoutePlan(request: SaveRoutePlanRequest): SaveRoutePlanResponse { error("not used") }
        override suspend fun listMyRoutePlans(limit: Int, offset: Int): RoutePlanListResponse {
            failure?.let { throw it }
            return RoutePlanListResponse(count = trips.size, routes = trips)
        }
    }
}
