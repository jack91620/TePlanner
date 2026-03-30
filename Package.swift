// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TePlanner",
    platforms: [
        .iOS(.v17) // We are targeting modern SwiftUI features.
    ],
    products: [
        .executable(name: "TePlannerApp", targets: ["TePlanner"])
    ],
    targets: [
        .executableTarget(
            name: "TePlanner",
            path: "Sources/TePlanner"
        )
    ]
)
