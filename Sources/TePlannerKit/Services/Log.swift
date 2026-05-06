import Foundation
import os

/// Centralized loggers backed by Apple's unified logging system. Every
/// emit lands in `log stream` on a tethered Mac (or in Console.app),
/// filterable by subsystem and category — see `make log-device`.
///
/// Why os.Logger over `print`:
/// - Filterable by subsystem/category from the host Mac.
/// - Captured in `sysdiagnose` and `log show` after the fact, even if
///   nobody was watching at the time.
/// - Honors privacy markers so token values never end up in archived
///   logs on a non-tethered device.
public enum Log {
    public static let subsystem = "com.teplanner.ios"

    /// HTTP traffic — request shape, response status, decoding outcomes.
    public static let api = Logger(subsystem: subsystem, category: "api")

    /// AuthSession state transitions and OAuth flow milestones (no
    /// actual token values).
    public static let auth = Logger(subsystem: subsystem, category: "auth")

    /// HomeViewModel: vehicle pick, wake retries, state polling.
    public static let vehicle = Logger(subsystem: subsystem, category: "vehicle")

    /// LoginView WebView lifecycle, callback URL detection, JS extraction.
    public static let oauth = Logger(subsystem: subsystem, category: "oauth")

    /// App lifecycle — AMap SDK init, RootView routing.
    public static let app = Logger(subsystem: subsystem, category: "app")

    /// Map view: marker updates, camera moves.
    public static let map = Logger(subsystem: subsystem, category: "map")

    /// POI search: query lifecycle, AMap responses.
    public static let search = Logger(subsystem: subsystem, category: "search")
}
