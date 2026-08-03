import SwiftUI

struct AgentToolsUpdateCompletionView: View {
    let result: AgentToolsUpdateResult
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Label("Agent Tools Updated", systemImage: "checkmark.circle.fill")
                .font(.title2)
                .bold()
                .foregroundStyle(.green)

            Text(result.detail)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Spacer()
                Button("Close", action: close)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}
