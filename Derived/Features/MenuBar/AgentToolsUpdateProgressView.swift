import SwiftUI

struct AgentToolsUpdateProgressView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Updating Agent Tools")
                .font(.title2)
                .bold()

            Text("Updating the CLI, MCP server, and installed agent integrations.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
