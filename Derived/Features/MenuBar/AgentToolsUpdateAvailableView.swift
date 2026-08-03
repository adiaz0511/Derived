import SwiftUI

struct AgentToolsUpdateAvailableView: View {
    let availability: AgentToolsUpdateAvailability
    let didCopyHomebrewCommand: Bool
    let update: () -> Void
    let copyCommand: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Label(title, systemImage: "arrow.down.circle.fill")
                .font(.title2)
                .bold()

            Text(message)
                .foregroundStyle(.secondary)

            if availability.installationKind == .homebrew {
                Text("derived integrations update")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: .rect(cornerRadius: 8))
            }

            Spacer()

            HStack {
                Spacer()
                Button("Not Now", action: close)
                    .keyboardShortcut(.cancelAction)

                if availability.installationKind == .homebrew {
                    Button(
                        didCopyHomebrewCommand ? "Command Copied" : "Copy Update Command",
                        systemImage: didCopyHomebrewCommand ? "checkmark" : "doc.on.doc",
                        action: copyCommand
                    )
                    .buttonStyle(.borderedProminent)
                    .accessibilityInputLabels(["Copy Update Command"])
                } else {
                    Button("Update Agent Tools", action: update)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding()
    }

    private var title: String {
        availability.installationKind == .homebrew
            ? "Update Agent Tools with Homebrew"
            : "Agent Tools Update Available"
    }

    private var message: String {
        if availability.installationKind == .homebrew {
            "Your Agent Tools are managed by Homebrew. Run the update command in Terminal to install version \(availability.availableVersion)."
        } else {
            "Version \(availability.availableVersion) updates the Derived CLI, MCP server, and agent skill."
        }
    }
}
