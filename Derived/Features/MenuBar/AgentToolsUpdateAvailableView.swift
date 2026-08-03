import SwiftUI

struct AgentToolsUpdateAvailableView: View {
    let availability: AgentToolsUpdateAvailability
    let didCopyHomebrewCommand: Bool
    let update: () -> Void
    let copyCommand: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            AgentToolsUpdateHeader(
                title: title,
                version: "\(availability.installedVersion) → \(availability.availableVersion)",
                message: message,
                systemImage: nil,
                tint: .accentColor
            )

            if availability.installationKind == .homebrew {
                Text("derived integrations update")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: .rect(cornerRadius: 8))
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Spacer()

                Button("Later", action: close)
                    .keyboardShortcut(.cancelAction)

                if availability.installationKind == .homebrew {
                    Button(
                        didCopyHomebrewCommand ? "Command Copied" : "Copy Command",
                        systemImage: didCopyHomebrewCommand ? "checkmark" : "doc.on.doc",
                        action: copyCommand
                    )
                    .buttonStyle(.borderedProminent)
                    .accessibilityInputLabels(["Copy Command"])
                } else {
                    Button("Update", action: update)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
    }

    private var title: String {
        availability.installationKind == .homebrew
            ? "Update with Homebrew"
            : "Update Agent Tools"
    }

    private var message: String {
        if availability.installationKind == .homebrew {
            "Homebrew manages this installation. Copy the command below and run it in Terminal."
        } else {
            "Updates the Derived CLI, MCP server, and installed agent integrations."
        }
    }
}
