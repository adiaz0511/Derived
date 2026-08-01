#if DEBUG
import Foundation

extension Notification.Name {
    static let panelStressDisclosure = Notification.Name("Derived.PanelStressDisclosure")
    static let panelStressAutomationDisclosure = Notification.Name("Derived.PanelStressAutomationDisclosure")
    static let panelStressPreferencesDisclosure = Notification.Name("Derived.PanelStressPreferencesDisclosure")
    static let panelStressScroll = Notification.Name("Derived.PanelStressScroll")
}

@MainActor
enum PanelStressRunner {
    private static let cycleCount = 10

    static func run(model: AppModel) async {
        guard await waitForScan(model: model) else { return }

        for _ in 1...cycleCount {
            for category in CleanupCategory.allCases {
                post(category: category, isExpanded: true)
                try? await Task.sleep(for: .milliseconds(75))
            }
            postSettings(isExpanded: true)
            try? await Task.sleep(for: .milliseconds(75))

            postScroll(target: .bottom)
            try? await Task.sleep(for: .milliseconds(200))
            postScroll(target: .top)
            try? await Task.sleep(for: .milliseconds(200))

            postSettings(isExpanded: false)
            try? await Task.sleep(for: .milliseconds(75))
            for category in CleanupCategory.allCases.reversed() {
                post(category: category, isExpanded: false)
                try? await Task.sleep(for: .milliseconds(75))
            }
        }
    }

    private static func waitForScan(model: AppModel) async -> Bool {
        for _ in 0..<1_200 {
            if model.report != nil { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    private static func post(category: CleanupCategory, isExpanded: Bool) {
        NotificationCenter.default.post(
            name: .panelStressDisclosure,
            object: nil,
            userInfo: [
                "category": category.rawValue,
                "isExpanded": isExpanded
            ]
        )
    }

    private static func postSettings(isExpanded: Bool) {
        NotificationCenter.default.post(
            name: .panelStressAutomationDisclosure,
            object: nil,
            userInfo: ["isExpanded": isExpanded]
        )
        NotificationCenter.default.post(
            name: .panelStressPreferencesDisclosure,
            object: nil,
            userInfo: ["isExpanded": isExpanded]
        )
    }

    private static func postScroll(target: PanelScrollTarget) {
        NotificationCenter.default.post(
            name: .panelStressScroll,
            object: nil,
            userInfo: ["target": target.rawValue]
        )
    }
}
#endif
