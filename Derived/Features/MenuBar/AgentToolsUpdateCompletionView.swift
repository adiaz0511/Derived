import SwiftUI

struct AgentToolsUpdateCompletionView: View {
    let result: AgentToolsUpdateResult
    let close: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            AgentToolsUpdateHeader(
                title: "Agent Tools Updated",
                version: nil,
                message: result.detail,
                systemImage: "checkmark.circle.fill",
                tint: .green
            )

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Spacer()

                Button("Close", action: close)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}
