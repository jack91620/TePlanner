package com.teplanner.ui.theme

import androidx.compose.ui.graphics.Color

// Tesla-style dark theme colors (matching mini-program)
val TeslaRed = Color(0xFFE82127)
val TeslaBlue = Color(0xFF3E6AE1)
val TeslaGreen = Color(0xFF34C759)  // iOS green

// Background colors
val DarkBackground = Color(0xFF171717)
val DarkSurface = Color(0xFF2A2A2A)
val DarkSurfaceVariant = Color(0xFF3A3A3A)

// Overlay colors
val OverlayBackground = Color(0x99000000)  // rgba(0,0,0,0.6)
val OverlayBackgroundDark = Color(0xBF000000)  // rgba(0,0,0,0.75)

// Text colors
val TextPrimary = Color(0xFFFFFFFF)
val TextSecondary = Color(0x99FFFFFF)  // rgba(255,255,255,0.6)
val TextTertiary = Color(0x66FFFFFF)   // rgba(255,255,255,0.4)
val TextHint = Color(0x80FFFFFF)       // rgba(255,255,255,0.5)

// Divider colors
val DividerColor = Color(0x14FFFFFF)   // rgba(255,255,255,0.08)

// Status colors
val StatusConnected = Color(0xFF34C759)
val StatusDisconnected = Color(0xFF8B8B8B)
val StatusCharging = Color(0xFF34C759)
val StatusDriving = Color(0xFF3E6AE1)
val StatusWarning = Color(0xFFFFB800)
val StatusError = Color(0xFFE82127)

// Battery colors
val BatteryHigh = Color(0xFF34C759)    // > 50%
val BatteryMedium = Color(0xB3E82127)  // 20-50% (error with alpha)
val BatteryLow = Color(0xFFE82127)     // < 20%
