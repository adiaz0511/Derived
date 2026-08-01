import Foundation

nonisolated enum PathDisplayFormat {
    static func location(
        for path: String,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> String {
        guard path.hasPrefix("/") else {
            return virtualLocation(for: path)
        }

        let standardizedPath = URL(filePath: path).standardizedFileURL.path
        let parentPath = URL(filePath: standardizedPath).deletingLastPathComponent().path
        let homePath = URL(filePath: homeDirectory).standardizedFileURL.path
        let parentComponents = components(of: parentPath)
        let homeComponents = components(of: homePath)

        let displayComponents: [String]
        if parentPath == homePath {
            displayComponents = ["Home"]
        } else if parentPath.hasPrefix(homePath + "/") {
            displayComponents = ["Home"] + parentComponents.dropFirst(homeComponents.count)
        } else if parentComponents.first == "Volumes", parentComponents.count > 1 {
            displayComponents = Array(parentComponents.dropFirst())
        } else {
            displayComponents = parentComponents
        }

        return displayComponents
            .map(readableComponent)
            .joined(separator: " › ")
    }

    private static func components(of path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    private static func readableComponent(_ component: String) -> String {
        switch component {
        case "DerivedData": "Derived Data"
        case "XCTestDevices": "XCTest Devices"
        case "DeviceSupport": "Device Support"
        default: component
        }
    }

    private static func virtualLocation(for path: String) -> String {
        let components = path
            .replacingOccurrences(of: "://", with: "/")
            .split(separator: "/")
            .dropLast()
            .map(String.init)
        return components.joined(separator: " › ")
    }
}
