import Foundation

/// Phase 9 — closed-loop VCP confirmation status.
public struct PendingCommand: Equatable, Sendable, Codable, Identifiable {
    public let id: Int
    public let capability: String
    public let expectedState: [String: JSONValue]
    public let dispatchedAt: Date
    public let confirmedAt: Date?
    public let timedOutAt: Date?
    /// "pending" | "confirmed" | "timed_out"
    public let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case capability
        case expectedState = "expected_state"
        case dispatchedAt = "dispatched_at"
        case confirmedAt = "confirmed_at"
        case timedOutAt = "timed_out_at"
        case status
    }

    public init(
        id: Int,
        capability: String,
        expectedState: [String: JSONValue],
        dispatchedAt: Date,
        confirmedAt: Date? = nil,
        timedOutAt: Date? = nil,
        status: String
    ) {
        self.id = id
        self.capability = capability
        self.expectedState = expectedState
        self.dispatchedAt = dispatchedAt
        self.confirmedAt = confirmedAt
        self.timedOutAt = timedOutAt
        self.status = status
    }
}

public struct PendingCommandListResponse: Equatable, Sendable, Codable {
    public let pending: [PendingCommand]
    public init(pending: [PendingCommand]) { self.pending = pending }
}

/// Phase 10 — sleep-aware command queue status.
public struct QueuedCommand: Equatable, Sendable, Codable, Identifiable {
    public let id: Int
    public let capability: String
    public let params: [String: JSONValue]
    public let dispatchPolicy: String
    public let queuedAt: Date
    public let sentAt: Date?
    public let droppedAt: Date?
    public let ttlSeconds: Int
    public let error: String?
    /// "queued" | "sent" | "dropped"
    public let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case capability
        case params
        case dispatchPolicy = "dispatch_policy"
        case queuedAt = "queued_at"
        case sentAt = "sent_at"
        case droppedAt = "dropped_at"
        case ttlSeconds = "ttl_seconds"
        case error
        case status
    }

    public init(
        id: Int,
        capability: String,
        params: [String: JSONValue],
        dispatchPolicy: String,
        queuedAt: Date,
        sentAt: Date? = nil,
        droppedAt: Date? = nil,
        ttlSeconds: Int,
        error: String? = nil,
        status: String
    ) {
        self.id = id
        self.capability = capability
        self.params = params
        self.dispatchPolicy = dispatchPolicy
        self.queuedAt = queuedAt
        self.sentAt = sentAt
        self.droppedAt = droppedAt
        self.ttlSeconds = ttlSeconds
        self.error = error
        self.status = status
    }
}

public struct QueuedCommandListResponse: Equatable, Sendable, Codable {
    public let queued: [QueuedCommand]
    public init(queued: [QueuedCommand]) { self.queued = queued }
}
