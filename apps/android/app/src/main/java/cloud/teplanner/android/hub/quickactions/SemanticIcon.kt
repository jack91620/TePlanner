package cloud.teplanner.android.hub.quickactions

/**
 * Platform-neutral icon vocabulary used inside share payloads.
 * Mirrors iOS SemanticIcon.swift exactly.
 *
 * Android stores SF Symbol names locally for cross-device sync
 * round-trip (HubIconLibrary maps SF → Material at render). Share
 * payloads use a third vocabulary (semantic IDs like "lock") that
 * each platform maps to its own icon system. iOS converts SF →
 * semantic at share-time; Android does the same.
 *
 * The 32 mappings here MUST match the iOS table line-for-line —
 * shares an action on iOS encoded "lock" must render the lock
 * icon on Android (and vice versa).
 *
 * Unknown semantic IDs fall back to "bolt.fill". Unknown SF
 * Symbols fall back to "bolt".
 */
object SemanticIcon {

    /// SF Symbol name → semantic ID. Used at share-serialize time.
    val symbolToSemantic: Map<String, String> = mapOf(
        // Security
        "lock.fill" to "lock",
        "lock.open.fill" to "unlock",
        "shield.lefthalf.filled" to "shield",
        "light.beacon.max.fill" to "beacon",
        "megaphone.fill" to "horn",
        // Doors/windows
        "door.left.hand.open" to "door",
        "suitcase.fill" to "trunk",
        "car.rear.fill" to "frunk",
        "rectangle.portrait.and.arrow.right.fill" to "exit",
        "sun.haze.fill" to "sunroof",
        // Climate
        "thermometer.medium" to "thermometer",
        "snowflake" to "cold",
        "moon.zzz.fill" to "sleep",
        "fan.fill" to "fan",
        "flame.fill" to "heat",
        // Charging
        "bolt.fill" to "bolt",
        "bolt.car.fill" to "ev",
        "ev.charger" to "charger",
        "battery.100" to "battery",
        "hand.raised.slash.fill" to "stop",
        // Media
        "play.fill" to "play",
        "pause.fill" to "pause",
        "speaker.wave.2.fill" to "volume",
        "speaker.slash.fill" to "mute",
        "music.note" to "music",
        // Other
        "location.fill" to "pin",
        "paperplane.fill" to "send",
        "hand.tap.fill" to "tap",
        "house.fill" to "home",
        "sparkles" to "magic",
        "star.fill" to "star",
        "gearshape.fill" to "gear",
    )

    val semanticToSymbol: Map<String, String> =
        symbolToSemantic.entries.associate { (k, v) -> v to k }

    const val DEFAULT_SYMBOL: String = "bolt.fill"
    const val DEFAULT_SEMANTIC: String = "bolt"

    fun semanticFor(symbol: String): String =
        symbolToSemantic[symbol] ?: DEFAULT_SEMANTIC

    fun symbolFor(semantic: String): String =
        semanticToSymbol[semantic] ?: DEFAULT_SYMBOL
}
