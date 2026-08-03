import AppKit
import Observation

@MainActor
final class StatusItemController {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let panelController: MenuBarPanelWindowController
    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?

    init(
        model: AppModel,
        softwareUpdateController: SoftwareUpdateController,
        agentToolsUpdateController: AgentToolsUpdateController
    ) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        panelController = MenuBarPanelWindowController(
            model: model,
            softwareUpdateController: softwareUpdateController,
            agentToolsUpdateController: agentToolsUpdateController
        )

        configureStatusButton()
        observeReclaimableBytes()
    }

    #if DEBUG
    func showPanelForTesting() {
        showPanel()
    }
    #endif

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: "Derived")
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseUp])
        updateStatusButton(reclaimableBytes: 0)
    }

    @objc private func togglePanel() {
        if panelController.window?.isVisible == true {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }
        panelController.show(relativeTo: button)
        installEventMonitors()
    }

    private func hidePanel() {
        panelController.hide()
        removeEventMonitors()
    }

    private func installEventMonitors() {
        removeEventMonitors()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hidePanel()
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.hidePanel()
            return nil
        }
    }

    private func removeEventMonitors() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private func observeReclaimableBytes() {
        withObservationTracking {
            updateStatusButton(reclaimableBytes: model.report?.recommendedBytes ?? 0)
        } onChange: { [self] in
            Task { @MainActor in
                observeReclaimableBytes()
            }
        }
    }

    private func updateStatusButton(reclaimableBytes: Int64) {
        guard let button = statusItem.button else { return }
        let formattedBytes = ByteCountFormat.string(reclaimableBytes)
        button.setAccessibilityLabel("Derived, \(formattedBytes) reclaimable")
    }
}
