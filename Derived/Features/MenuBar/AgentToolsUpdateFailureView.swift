import SwiftUI

struct AgentToolsUpdateFailureView: View {
    let availability: AgentToolsUpdateAvailability
    let message: String
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Label("Agent Tools Could Not Be Updated", systemImage: "exclamationmark.triangle.fill")
                .font(.title2)
                .bold()
                .foregroundStyle(.red)

            Text("Your existing installation was not changed. Review the error and try again.")
                .foregroundStyle(.secondary)

            Text(message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: .rect(cornerRadius: 8))

            Spacer()

            HStack {
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
        .padding()
    }
}
