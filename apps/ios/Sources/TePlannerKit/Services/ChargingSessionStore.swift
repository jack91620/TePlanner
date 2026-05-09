import Foundation

/// Persistence + retrieval of `ChargingSession` records. Protocol-
/// first so tests can inject `InMemoryChargingSessionStore` without
/// touching UserDefaults.
public protocol ChargingSessionStore: AnyObject {
    /// Returns sessions newest-first. `limit == nil` means unbounded.
    func recent(limit: Int?) -> [ChargingSession]
    /// Currently-active (no endAt) session if any. There can only be
    /// one at a time — the tracker enforces that invariant.
    func ongoing() -> ChargingSession?
    /// Append a new session. Existing record with the same id is
    /// overwritten so callers can use this for both create + finalize.
    func upsert(_ session: ChargingSession)
    /// Remove all stored sessions. Used by tests + a hypothetical
    /// "reset stats" UI knob.
    func clear()
}

public final class UserDefaultsChargingSessionStore: ChargingSessionStore {
    public static let shared = UserDefaultsChargingSessionStore()

    private let defaults: UserDefaults
    private let key = "charging_sessions_v1"
    /// Where corrupt blobs are quarantined when decode fails — the
    /// raw Data plus the first decode error get logged to UserDefaults
    /// so the user can be prompted to file a report instead of just
    /// silently losing their charging history.
    private let backupKey = "charging_sessions_v1.broken"
    private let queue = DispatchQueue(label: "com.teplanner.charging-store", qos: .utility)

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func recent(limit: Int?) -> [ChargingSession] {
        let all = readAll()
        let sorted = all.sorted { $0.startAt > $1.startAt }
        if let limit { return Array(sorted.prefix(limit)) }
        return sorted
    }

    public func ongoing() -> ChargingSession? {
        readAll().first(where: { $0.isOngoing })
    }

    public func upsert(_ session: ChargingSession) {
        queue.sync {
            var all = readAllUnsynced()
            if let idx = all.firstIndex(where: { $0.id == session.id }) {
                all[idx] = session
            } else {
                all.append(session)
            }
            writeAllUnsynced(all)
        }
    }

    public func clear() {
        queue.sync {
            writeAllUnsynced([])
        }
    }

    // MARK: - private

    private func readAll() -> [ChargingSession] {
        queue.sync { readAllUnsynced() }
    }

    private func readAllUnsynced() -> [ChargingSession] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([ChargingSession].self, from: data)
        } catch {
            // Don't drop the data on the floor: copy the raw blob to a
            // backup key so a future migration / debugging session can
            // recover. Then return [] so the rest of the app keeps
            // working. `hasCorruptBackup` lets the UI surface a
            // 'history may be incomplete' banner if needed.
            if defaults.data(forKey: backupKey) == nil {
                defaults.set(data, forKey: backupKey)
                Log.app.error("charging-session decode failed: \(error.localizedDescription, privacy: .public) — \(data.count, privacy: .public)B blob backed up to \(self.backupKey, privacy: .public)")
            } else {
                Log.app.error("charging-session decode failed: \(error.localizedDescription, privacy: .public) — backup slot already taken, dropping current blob")
            }
            return []
        }
    }

    /// True iff a previous decode failure quarantined a blob into
    /// `backupKey`. Tests + UI can prompt the user to inspect /
    /// export the broken data instead of silently losing it.
    public var hasCorruptBackup: Bool {
        queue.sync { defaults.data(forKey: backupKey) != nil }
    }

    /// Returns the raw quarantined blob (if any). Caller decides what
    /// to do — share via UIActivityViewController, write to a file,
    /// or just inspect in the debugger.
    public func corruptBackup() -> Data? {
        queue.sync { defaults.data(forKey: backupKey) }
    }

    /// Drop the quarantined blob — call after the user has saved it
    /// elsewhere or confirmed they don't need it.
    public func clearCorruptBackup() {
        queue.sync { defaults.removeObject(forKey: backupKey) }
    }

    private func writeAllUnsynced(_ sessions: [ChargingSession]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            defaults.set(data, forKey: key)
        } catch {
            Log.app.error("charging-session encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// Test double — keeps everything in memory.
public final class InMemoryChargingSessionStore: ChargingSessionStore {
    private var sessions: [ChargingSession] = []
    public init() {}
    public func recent(limit: Int?) -> [ChargingSession] {
        let sorted = sessions.sorted { $0.startAt > $1.startAt }
        if let limit { return Array(sorted.prefix(limit)) }
        return sorted
    }
    public func ongoing() -> ChargingSession? {
        sessions.first(where: { $0.isOngoing })
    }
    public func upsert(_ session: ChargingSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.append(session)
        }
    }
    public func clear() { sessions.removeAll() }
}
