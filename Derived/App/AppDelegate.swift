import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let softwareUpdateController = SoftwareUpdateController()
    private lazy var automationMonitor = CleanupAutomationMonitor(model: model)
    private var statusItemController: StatusItemController?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(
            model: model,
            softwareUpdateController: softwareUpdateController
        )
        automationMonitor.start()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.automationMonitor.checkNow()
            }
        }

        #if DEBUG
        if CommandLine.arguments.contains("--show-panel")
            || CommandLine.arguments.contains("--stress-panel") {
            statusItemController?.showPanelForTesting()
        }
        if CommandLine.arguments.contains("--stress-panel") {
            Task {
                await PanelStressRunner.run(model: model)
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        automationMonitor.stop()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
