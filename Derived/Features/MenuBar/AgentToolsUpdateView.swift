import SwiftUI

struct AgentToolsUpdateView: View {
    let controller: AgentToolsUpdateController
    let close: () -> Void

    var body: some View {
        Group {
            switch controller.state {
            case .available(let availability):
                AgentToolsUpdateAvailableView(
                    availability: availability,
                    didCopyHomebrewCommand: controller.didCopyHomebrewCommand,
                    update: update,
                    copyCommand: controller.copyHomebrewCommand,
                    close: postpone
                )
            case .updating:
                AgentToolsUpdateProgressView()
            case .completed(let result):
                AgentToolsUpdateCompletionView(result: result, close: close)
            case .failed(let availability, let message):
                AgentToolsUpdateFailureView(
                    availability: availability,
                    message: message,
                    retry: update,
                    close: close
                )
            case .idle, .checking:
                AgentToolsUpdateProgressView()
            }
        }
        .frame(width: 460)
        .frame(minHeight: 240)
    }

    private func update() {
        Task { await controller.installUpdate() }
    }

    private func postpone() {
        controller.deferUpdate()
        close()
    }
}
