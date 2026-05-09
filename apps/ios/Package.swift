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
    dependencies: [
        // Phase C — generated OpenAPI client. Lives outside this
        // package so Phase F (Android) and Phase G (HarmonyOS) can
        // share the same source-of-truth /openapi.json snapshot.
        // Phase D will switch APIService.swift to consume this SDK
        // instead of hand-rolled Codable structs.
        .package(path: "../../packages/clients/swift"),
    ],
    targets: [
        .target(
            name: "TePlannerKit",
            dependencies: [
                .product(name: "TePlannerAPI", package: "swift"),
            ],
            path: "Sources/TePlannerKit"
        ),
        .testTarget(
            name: "TePlannerTests",
            dependencies: ["TePlannerKit"],
            path: "Tests/TePlannerTests"
        )
    ]
)
