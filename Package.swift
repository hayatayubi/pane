// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pane",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pane",
            path: "Sources/Pane",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
