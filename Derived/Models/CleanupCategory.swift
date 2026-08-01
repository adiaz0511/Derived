import Foundation

nonisolated enum CleanupCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case derivedData
    case previewData
    case xctestDevices
    case unavailableSimulators
    case redundantSimulators
    case simulatorRuntimes
    case deviceSupport
    case logs
    case caches
    case archives
    case temporaryData

    var id: Self { self }

    var title: String {
        switch self {
        case .derivedData: "Derived Data"
        case .previewData: "SwiftUI Preview Data"
        case .xctestDevices: "XCTest Devices"
        case .unavailableSimulators: "Unavailable Simulators"
        case .redundantSimulators: "Redundant Simulators"
        case .simulatorRuntimes: "Simulator Runtimes"
        case .deviceSupport: "Device Support"
        case .logs: "Xcode Logs"
        case .caches: "Safe Xcode Caches"
        case .archives: "Archives"
        case .temporaryData: "Other Temporary Data"
        }
    }

    var symbolName: String {
        switch self {
        case .derivedData: "hammer"
        case .previewData: "rectangle.on.rectangle"
        case .xctestDevices: "testtube.2"
        case .unavailableSimulators: "iphone.slash"
        case .redundantSimulators: "square.on.square"
        case .simulatorRuntimes: "shippingbox"
        case .deviceSupport: "cable.connector"
        case .logs: "doc.text"
        case .caches: "internaldrive"
        case .archives: "archivebox"
        case .temporaryData: "clock.arrow.circlepath"
        }
    }

    var summary: String {
        switch self {
        case .derivedData: "Build products, indexes, and intermediate files that Xcode can regenerate."
        case .previewData: "Simulator data created for SwiftUI previews."
        case .xctestDevices: "Cloned devices created while running automated tests."
        case .unavailableSimulators: "Simulator devices whose installed runtime is unavailable."
        case .redundantSimulators: "Multiple inactive devices with the same name and runtime."
        case .simulatorRuntimes: "Installed platform runtimes. Runtimes are never selected automatically."
        case .deviceSupport: "Support files copied for physical iPhone and Apple Watch devices."
        case .logs: "Diagnostic records written by Xcode and CoreSimulator."
        case .caches: "Regenerable Xcode and CoreSimulator cache files."
        case .archives: "Released builds and dSYMs. Archives are never selected automatically."
        case .temporaryData: "Other known Xcode-generated support and temporary data."
        }
    }
}
