import SwiftUI

struct AgentToolsUpdateProgressView: View {
    var body: some View {
        VStack {
            ProgressView()
                .controlSize(.large)
            Text("Updating Agent Tools")
                .font(.title2)
                .bold()
            Text("Derived is replacing the CLI, MCP server, and installed agent skills.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
