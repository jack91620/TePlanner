import Foundation

/// Persistence for the "next departure" schedule. Single-slot — set
/// overwrites previous, clear removes it. If the previously-scheduled
/// departure has already passed, `current()` lazily prunes it to nil
/// so the UI doesn't have to filter.
public protocol ScheduledDepartureStore: AnyObject {
    func current() -> ScheduledDeparture?
    func save(_ departure: ScheduledDeparture)
    func clear()
}

public final class UserDefaultsScheduledDepartureStore: ScheduledDepartureStore {
    public static let shared = UserDefaultsScheduledDepartureStore()

    private let defaults: UserDefaults
    private let key = "scheduled_departure_v1"
    private let now: () -> Date

    public init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    public func current() -> ScheduledDeparture? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let scheduled = try? JSONDecoder().decode(ScheduledDeparture.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        if !scheduled.isInFuture(now: now()) {
            defaults.removeObject(forKey: key)
            return nil
        }
        return scheduled
    }

    public func save(_ departure: ScheduledDeparture) {
        guard let data = try? JSONEncoder().encode(departure) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}

public final class InMemoryScheduledDepartureStore: ScheduledDepartureStore {
    private var stored: ScheduledDeparture?
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    public func current() -> ScheduledDeparture? {
        guard let stored, stored.isInFuture(now: now()) else {
            self.stored = nil
            return nil
        }
        return stored
    }
    public func save(_ departure: ScheduledDeparture) { stored = departure }
    public func clear() { stored = nil }
}
