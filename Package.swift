// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TePlanner",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TePlannerKit", targets: ["TePlannerKit"])
    ],
    targets: [
        .target(
            name: "TePlannerKit",
            path: "Sources/TePlannerKit"
        ),
        .testTarget(
            name: "TePlannerTests",
            dependencies: ["TePlannerKit"],
            path: "Tests/TePlannerTests"
        )
    ]
)
