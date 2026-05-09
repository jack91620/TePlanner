package cloud.teplanner.api.apis

import cloud.teplanner.api.infrastructure.CollectionFormats.*
import retrofit2.http.*
import retrofit2.Response
import okhttp3.RequestBody
import com.squareup.moshi.Json

import cloud.teplanner.api.models.HTTPValidationError
import cloud.teplanner.api.models.RecentFiresResponse
import cloud.teplanner.api.models.RuleCreateRequest
import cloud.teplanner.api.models.RuleListResponse
import cloud.teplanner.api.models.RuleOrderRequest
import cloud.teplanner.api.models.RuleResponse
import cloud.teplanner.api.models.RuleUpdateRequest
import cloud.teplanner.api.models.SnoozeListResponse
import cloud.teplanner.api.models.SnoozeRequest
import cloud.teplanner.api.models.SnoozeResponse
import cloud.teplanner.api.models.TelemetryStateResponse

interface AutomationsApi {
    /**
     * POST api/v1/automations/
     * Create Rule
     * 
     * Responses:
     *  - 201: Successful Response
     *  - 422: Validation Error
     *
     * @param ruleCreateRequest 
     * @return [RuleResponse]
     */
    @POST("api/v1/automations/")
    suspend fun createRuleApiV1AutomationsPost(@Body ruleCreateRequest: RuleCreateRequest): Response<RuleResponse>

    /**
     * DELETE api/v1/automations/{rule_id}
     * Delete Rule
     * 
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param ruleId 
     * @return [kotlin.Any]
     */
    @DELETE("api/v1/automations/{rule_id}")
    suspend fun deleteRuleApiV1AutomationsRuleIdDelete(@Path("rule_id") ruleId: kotlin.String): Response<kotlin.Any>

    /**
     * GET api/v1/automations/state
     * Get Telemetry State
     * Return the user&#39;s telemetry-recorded entity state — the &#x60;&#x60;tel:*&#x60;&#x60; rows the Fleet Telemetry consumer writes into automation_state.  iOS calls this on each polling tick, before evaluating rules, and seeds the local engine memory with the server&#39;s &#x60;&#x60;since&#x60;&#x60; timestamps. The interpreter then prefers the earlier of (locally observed, server telemetry) when computing duration. That&#39;s what closes the \&quot;已开启 0 分钟\&quot; gap: the iOS HubView pill now reports the same elapsed time the server reports in push notifications.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [TelemetryStateResponse]
     */
    @GET("api/v1/automations/state")
    suspend fun getTelemetryStateApiV1AutomationsStateGet(): Response<TelemetryStateResponse>

    /**
     * GET api/v1/automations/capabilities
     * List Capabilities
     * Registry introspection. iOS visual builder calls this once at boot to populate the action-block picker.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [kotlin.collections.Map<kotlin.String, kotlin.collections.List<kotlin.Any>>]
     */
    @GET("api/v1/automations/capabilities")
    suspend fun listCapabilitiesApiV1AutomationsCapabilitiesGet(): Response<kotlin.collections.Map<kotlin.String, kotlin.collections.List<kotlin.Any>>>

    /**
     * GET api/v1/automations/recent-fires
     * List Recent Fires
     * Recent rule-fire timeline for the user. Drives the iOS &#39;活动&#39; page — answers &#39;did my露营 rule fire today?&#39; without the user having to scrub through notification center.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param limit  (optional, default to 50)
     * @return [RecentFiresResponse]
     */
    @GET("api/v1/automations/recent-fires")
    suspend fun listRecentFiresApiV1AutomationsRecentFiresGet(@Query("limit") limit: kotlin.Int? = 50): Response<RecentFiresResponse>

    /**
     * GET api/v1/automations/
     * List Rules
     * List all of the user&#39;s rules. Lazy-seeds the presets on first call (when user has zero rules). Order is canonical: each preset in its ALL_PRESETS-declared position, user-authored rules after, by creation time. Each rule includes &#x60;&#x60;last_fired_at&#x60;&#x60; — the most recent PushedAlert.pushed_at for that rule&#39;s kind.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [RuleListResponse]
     */
    @GET("api/v1/automations/")
    suspend fun listRulesApiV1AutomationsGet(): Response<RuleListResponse>

    /**
     * GET api/v1/automations/snoozes
     * List Snoozes
     * List all active (snoozed_until_utc &gt; now) snoozes for the user. Stale rows (past their window) are filtered server-side; the client never sees them, so iOS doesn&#39;t need to time-check.
     * Responses:
     *  - 200: Successful Response
     *
     * @return [SnoozeListResponse]
     */
    @GET("api/v1/automations/snoozes")
    suspend fun listSnoozesApiV1AutomationsSnoozesGet(): Response<SnoozeListResponse>

    /**
     * PUT api/v1/automations/order
     * Reorder Rules
     * Persist a user-defined display order. Returns the full rule list in the new canonical order so iOS can replace its in-memory cache in one round-trip.  All rule_ids must belong to the requesting user; we 404 on the first mismatch (defensive — silent skipping would leak existence). Duplicates within rule_ids are rejected (400) so position is well-defined.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param ruleOrderRequest 
     * @return [RuleListResponse]
     */
    @PUT("api/v1/automations/order")
    suspend fun reorderRulesApiV1AutomationsOrderPut(@Body ruleOrderRequest: RuleOrderRequest): Response<RuleListResponse>

    /**
     * POST api/v1/automations/{rule_id}/snooze
     * Snooze Rule
     * Snooze &#x60;&#x60;rule_id&#x60;&#x60; until &#x60;&#x60;until&#x60;&#x60; (absolute UTC) or for &#x60;&#x60;hours&#x60;&#x60; from now. Exactly one of the two must be provided. Replaces any existing snooze on that rule (UNIQUE on rule_id).
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param ruleId 
     * @param snoozeRequest 
     * @return [SnoozeResponse]
     */
    @POST("api/v1/automations/{rule_id}/snooze")
    suspend fun snoozeRuleApiV1AutomationsRuleIdSnoozePost(@Path("rule_id") ruleId: kotlin.String, @Body snoozeRequest: SnoozeRequest): Response<SnoozeResponse>

    /**
     * DELETE api/v1/automations/{rule_id}/snooze
     * Unsnooze Rule
     * Clear any active snooze on &#x60;&#x60;rule_id&#x60;&#x60;. 404 if the rule itself doesn&#39;t exist; idempotent on a rule with no active snooze.
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param ruleId 
     * @return [kotlin.Any]
     */
    @DELETE("api/v1/automations/{rule_id}/snooze")
    suspend fun unsnoozeRuleApiV1AutomationsRuleIdSnoozeDelete(@Path("rule_id") ruleId: kotlin.String): Response<kotlin.Any>

    /**
     * PUT api/v1/automations/{rule_id}
     * Update Rule
     * 
     * Responses:
     *  - 200: Successful Response
     *  - 422: Validation Error
     *
     * @param ruleId 
     * @param ruleUpdateRequest 
     * @return [RuleResponse]
     */
    @PUT("api/v1/automations/{rule_id}")
    suspend fun updateRuleApiV1AutomationsRuleIdPut(@Path("rule_id") ruleId: kotlin.String, @Body ruleUpdateRequest: RuleUpdateRequest): Response<RuleResponse>

}
