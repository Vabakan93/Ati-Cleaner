// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MacCleanerCore"
        ),
        .executableTarget(
            name: "MacCleaner",
            dependencies: ["MacCleanerCore"]
        )
    ]
)