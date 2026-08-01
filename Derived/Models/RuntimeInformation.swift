import Foundation

nonisolated struct RuntimeInformation: Identifiable, Hashable, Codable, Sendable {
    enum Platform: String, CaseIterable, Codable, Sendable {
        case iOS
        case watchOS
        case tvOS
        case visionOS
        case macOS
        case unknown

        var symbolName: String {
            switch self {
            case .iOS: "iphone"
            case .watchOS: "applewatch"
            case .tvOS: "appletv"
            case .visionOS: "vision.pro"
            case .macOS: "macbook"
            case .unknown: "shippingbox"
            }
        }
    }

    let id: String
    let name: String
    let platform: Platform
    let version: String
    let buildVersion: String?
    let isPrerelease: Bool
    let isNewestForPlatform: Bool
    let isAvailable: Bool
}
