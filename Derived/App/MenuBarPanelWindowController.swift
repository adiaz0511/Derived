import AppKit
import SwiftUI

@MainActor
final class MenuBarPanelWindowController: NSWindowController {
    private let hostingController: NSHostingController<MenuBarPanel>

    init(
        model: AppModel,
        softwareUpdateController: SoftwareUpdateController,
        agentToolsUpdateController: AgentToolsUpdateController
    ) {
        let contentSize = NSSize(
            width: DesignMetrics.panelWidth,
            height: DesignMetrics.panelHeight
        )
        let panel = MenuBarPanelWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostingController = NSHostingController(
            rootView: MenuBarPanel(
                model: model,
                softwareUpdateController: softwareUpdateController,
                agentToolsUpdateController: agentToolsUpdateController
            )
        )

        super.init(window: panel)

        hostingController.sizingOptions = []
        hostingController.view.frame = NSRect(origin: .zero, size: contentSize)
        hostingController.view.autoresizingMask = [.width, .height]

        panel.contentViewController = hostingController
        panel.setContentSize(contentSize)
        panel.contentMinSize = contentSize
        panel.contentMaxSize = contentSize
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = DesignMetrics.cardCornerRadius
        hostingController.view.layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(relativeTo statusButton: NSStatusBarButton) {
        guard let panel = window as? NSPanel,
              let statusWindow = statusButton.window else { return }

        let buttonRectInWindow = statusButton.convert(statusButton.bounds, to: nil)
        let buttonRectOnScreen = statusWindow.convertToScreen(buttonRectInWindow)
        let screen = statusWindow.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero
        let panelSize = panel.frame.size
        let idealX = buttonRectOnScreen.midX - panelSize.width / 2
        let x = min(max(idealX, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        let y = buttonRectOnScreen.minY - panelSize.height - 6

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
