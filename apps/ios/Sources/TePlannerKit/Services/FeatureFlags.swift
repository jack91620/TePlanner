import Foundation

/// Lightweight feature-flag registry. Each flag has a hard-coded
/// production default and a UserDefaults override key — TestFlight /
/// dev builds can flip flags via the Settings sheet without shipping
/// a new App Store binary.
///
/// Why not a fancier system: we have one flag and 6-week ICP/软著
/// process ahead. A `bool { get }` over UserDefaults is fine.
@MainActor
public enum FeatureFlags {

    public enum Flag: String, CaseIterable {
        /// Hides the Hub "充电规划" entry + the in-flight trip card
        /// while we polish the multi-stop trip pipeline. Two production
        /// bugs surfaced in the same evening (active_trip dead feature,
        /// destination key mismatch); we want to ship a 1.0 without
        /// this feature and re-enable once it's stable. Default OFF.
        case chargingPlanning = "feature.planning.enabled"

        /// Hard-coded production default. iOS reads this when the
        /// UserDefaults key is absent.
        public var defaultValue: Bool {
            switch self {
            case .chargingPlanning: return false
            }
        }

        /// User-facing label for the Settings toggle.
        public var displayName: String {
            switch self {
            case .chargingPlanning: return "充电规划"
            }
        }

        /// One-line explanation under the toggle. Tells testers why
        /// this is gated and what to expect when they flip it.
        public var description: String {
            switch self {
            case .chargingPlanning:
                return "多段充电路线规划与发送至车机。正在打磨中，关闭后 Hub 不显示「充电规划」入口及进行中行程卡片。"
            }
        }
    }

    /// Read a flag. Looks up the UserDefaults override first (so
    /// testers can flip via Settings); falls back to the compiled
    /// default. The key namespace `feature.*` is reserved for this
    /// registry and must never collide with other prefs.
    public static func isOn(_ flag: Flag) -> Bool {
        if let v = UserDefaults.standard.object(forKey: flag.rawValue) as? Bool {
            return v
        }
        return flag.defaultValue
    }

    /// Set the override. Persists across launches. Pass `nil` to
    /// remove the override and fall back to the default — useful for
    /// "reset to defaults" debug actions.
    public static func setOverride(_ flag: Flag, to value: Bool?) {
        if let value {
            UserDefaults.standard.set(value, forKey: flag.rawValue)
        } else {
            UserDefaults.standard.removeObject(forKey: flag.rawValue)
        }
    }

    /// True when this binary is running in TestFlight (sandbox
    /// receipt) or the simulator/dev install (no receipt at all).
    /// Used to gate the Settings toggle so App Store users don't see
    /// debug controls. A separate property — not a flag — because it
    /// describes the *binary*, not user preference.
    public static var isInternalBuild: Bool {
        #if DEBUG
        return true
        #else
        guard let url = Bundle.main.appStoreReceiptURL else {
            // No receipt at all → dev install (e.g. side-loaded). Treat
            // as internal so engineers can still flip flags from the UI.
            return true
        }
        return url.lastPathComponent == "sandboxReceipt"
        #endif
    }
}
