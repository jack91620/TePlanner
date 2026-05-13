import Foundation

/// What POST /api/v1/llm/configure expects + returns. Mirrors the
/// backend's `ConfigureRequest` / `ConfigureResponse` (Phase 12).
///
/// Single-turn for v1 — each user message is an independent request.
/// Multi-turn (history[]) would require state on the iOS side which
/// isn't worth the cost until we see real ambiguity bottlenecks.

public struct LLMConfigureRequest: Codable {
    public let message: String
    /// "auto" = let the LLM decide; "automation" or "quick_action"
    /// to constrain. The UI passes a constraint when the user came
    /// in via "+" on the automations list vs. the hub quick actions
    /// section so the LLM doesn't propose the wrong shape.
    public let target: String

    public init(message: String, target: String = "auto") {
        self.message = message
        self.target = target
    }
}

public struct LLMConfigureResponse: Codable, Equatable {
    public let intent: Intent
    public let summary: String
    public let name: String?
    public let clarification: String?
    public let automationSpec: JSONValue?
    public let quickAction: JSONValue?
    /// Server-side registry-check errors. Empty / nil = the spec
    /// round-trips through the real capability registry and is safe
    /// to save; non-empty = the LLM hallucinated something, surface
    /// the message so the user can rephrase.
    public let validationErrors: [String]?

    public enum Intent: String, Codable {
        case createAutomation = "create_automation"
        case createQuickAction = "create_quick_action"
        case askClarification = "ask_clarification"
    }

    public init(
        intent: Intent,
        summary: String,
        name: String? = nil,
        clarification: String? = nil,
        automationSpec: JSONValue? = nil,
        quickAction: JSONValue? = nil,
        validationErrors: [String]? = nil
    ) {
        self.intent = intent
        self.summary = summary
        self.name = name
        self.clarification = clarification
        self.automationSpec = automationSpec
        self.quickAction = quickAction
        self.validationErrors = validationErrors
    }

    public enum CodingKeys: String, CodingKey {
        case intent, summary, name, clarification
        case automationSpec = "automation_spec"
        case quickAction = "quick_action"
        case validationErrors = "validation_errors"
    }

    /// True iff the LLM produced a usable spec — iOS uses this to
    /// gate the "确认创建" button.
    public var isReadyToSave: Bool {
        switch intent {
        case .askClarification:
            return false
        case .createAutomation, .createQuickAction:
            return (validationErrors ?? []).isEmpty
        }
    }
}
