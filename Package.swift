// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AtiCleaner",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AtiCleaner", targets: ["AtiCleanerApp"]),
        .library(name: "AtiCleanerCore", targets: ["AtiCleanerCore"])
    ],
    targets: [
        .target(
            name: "AtiCleanerCore",
            path: "Sources/AtiCleanerCore"
        ),
        .executableTarget(
            name: "AtiCleanerApp",
            dependencies: ["AtiCleanerCore"],
            path: "Sources/AtiCleanerApp"
        ),
        .testTarget(
            name: "AtiCleanerCoreTests",
            dependencies: ["AtiCleanerCore"],
            path: "Tests/AtiCleanerCoreTests"
        )
    ]
)
