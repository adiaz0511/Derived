import SwiftUI

struct AgentToolsUpdateFailureView: View {
    let availability: AgentToolsUpdateAvailability
    let message: String
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            AgentToolsUpdateHeader(
                title: "Agent Tools Could Not Be Updated",
                version: nil,
                message: "Your existing installation was not changed. Review the error and try again.",
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            )

            Text(message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: .rect(cornerRadius: 8))

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Spacer()

                Button("Close", action: close)
                    .keyboardShortcut(.cancelAction)
                if availability.installationKind == .dmg {
                    Button("Try Again", action: retry)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
    }
}
