import Foundation

/// Platform-neutral icon vocabulary used inside share payloads.
///
/// iOS stores `HubAction.icon` as an SF Symbol name ("lock.fill"),
/// Android stores Material icon names, Harmony stores ArkUI icon
/// names. None of those vocabularies match — so the share wire
/// format uses a third vocabulary (semantic IDs like "lock") that
/// each platform maps to its own native icon.
///
/// Single source of truth lives here in TePlannerKit; the
/// equivalent table in Android (Kotlin enum) and Harmony (ArkTS
/// const map) must stay in lockstep — protected by a unit test
/// in each platform that asserts every HubActionIconLibrary
/// entry has a semantic ID, and round-trips cleanly.
///
/// New icons added to HubActionIconLibrary MUST add a row here
/// (and the matching row in the other two platforms) before the
/// share format will tolerate them. An unmapped icon at share
/// time falls back to the generic semantic ID `bolt` so the
/// import side gets something reasonable.
public enum SemanticIcon {
    /// SF Symbol name → semantic ID. Used when serializing a
    /// HubAction for a share payload on iOS.
    public static let symbolToSemantic: [String: String] = [
        // Security
        "lock.fill": "lock",
        "lock.open.fill": "unlock",
        "shield.lefthalf.filled": "shield",
        "light.beacon.max.fill": "beacon",
        "megaphone.fill": "horn",
        // Doors/windows
        "door.left.hand.open": "door",
        "suitcase.fill": "trunk",
        "car.rear.fill": "frunk",
        "rectangle.portrait.and.arrow.right.fill": "exit",
        "sun.haze.fill": "sunroof",
        // Climate
        "thermometer.medium": "thermometer",
        "snowflake": "cold",
        "moon.zzz.fill": "sleep",
        "fan.fill": "fan",
        "flame.fill": "heat",
        // Charging
        "bolt.fill": "bolt",
        "bolt.car.fill": "ev",
        "ev.charger": "charger",
        "battery.100": "battery",
        "hand.raised.slash.fill": "stop",
        // Media
        "play.fill": "play",
        "pause.fill": "pause",
        "speaker.wave.2.fill": "volume",
        "speaker.slash.fill": "mute",
        "music.note": "music",
        // Other
        "location.fill": "pin",
        "paperplane.fill": "send",
        "hand.tap.fill": "tap",
        "house.fill": "home",
        "sparkles": "magic",
        "star.fill": "star",
        "gearshape.fill": "gear",
    ]

    /// Inverse table — semantic ID → SF Symbol. Used when
    /// importing a share payload on iOS.
    public static let semanticToSymbol: [String: String] = {
        var out: [String: String] = [:]
        for (sym, sem) in symbolToSemantic {
            out[sem] = sym
        }
        return out
    }()

    /// Fallback used when the input doesn't match. Both directions
    /// have a stable default so importing a payload that pre-dates
    /// our icon table still produces something the user can see.
    public static let defaultSymbol = "bolt.fill"
    public static let defaultSemantic = "bolt"

    /// Convert an iOS SF Symbol to the share-wire semantic ID.
    public static func semantic(for symbol: String) -> String {
        symbolToSemantic[symbol] ?? defaultSemantic
    }

    /// Convert a share-wire semantic ID back to an iOS SF Symbol.
    public static func symbol(for semantic: String) -> String {
        semanticToSymbol[semantic] ?? defaultSymbol
    }
}
