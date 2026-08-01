// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Derived",
    platforms: [.macOS("26.4")],
    products: [
        .library(name: "DerivedCore", targets: ["DerivedCore"]),
        .executable(name: "derived", targets: ["DerivedCLI"]),
        .executable(name: "derived-mcp", targets: ["DerivedMCP"])
    ],
    targets: [
        .target(
            name: "DerivedCore",
            path: "Derived",
            exclude: [
                "App",
                "Assets.xcassets",
                "DerivedApp.swift",
                "Features",
                "Models/PanelScrollTarget.swift",
                "Services/CleanupAutomationMonitor.swift",
                "Services/LaunchAtLoginController.swift",
                "Services/PanelStressRunner.swift",
                "Services/SettingsStore.swift",
                "Shared/DesignMetrics.swift"
            ],
            swiftSettings: [.unsafeFlags(["-default-isolation=MainActor"])]
        ),
        .executableTarget(
            name: "DerivedCLI",
            dependencies: ["DerivedCore"],
            path: "Tools/DerivedCLI"
        ),
        .executableTarget(
            name: "DerivedMCP",
            dependencies: ["DerivedCore"],
            path: "Tools/DerivedMCP"
        ),
        .testTarget(
            name: "DerivedCoreTests",
            dependencies: ["DerivedCore"],
            path: "DerivedCoreTests"
        ),
        .testTarget(
            name: "DerivedCLITests",
            dependencies: ["DerivedCLI", "DerivedCore"],
            path: "DerivedCLITests"
        )
    ],
    swiftLanguageModes: [.v5]
)
