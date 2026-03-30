// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TePlanner",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TePlannerApp", targets: ["TePlanner"])
    ],
    targets: [
        // The main application executable, which will be very lightweight.
        .executableTarget(
            name: "TePlanner",
            dependencies: ["TePlannerKit"], // Depends on our new library
            path: "Sources/TePlanner"
        ),
        // The shared library containing all UI, logic, and services.
        .target(
            name: "TePlannerKit",
            path: "Sources/TePlannerKit"
        ),
        // The test target, which now depends on the library, not the executable.
        .testTarget(
            name: "TePlannerTests",
            dependencies: ["TePlannerKit"],
            path: "Tests/TePlannerTests"
        )
    ]
)
