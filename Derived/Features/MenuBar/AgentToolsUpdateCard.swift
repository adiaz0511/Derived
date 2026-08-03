import SwiftUI

struct AgentToolsUpdateCard: View {
    let controller: AgentToolsUpdateController
    let showUpdate: () -> Void

    var body: some View {
        if let availability = controller.availableUpdate, controller.shouldShowCard {
            Button(action: showUpdate) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading) {
                        Text("Agent Tools Update Available")
                            .bold()
                        Text("Version \(availability.availableVersion.description) is ready to install.")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .panelCard()
            .accessibilityHint("Shows options for updating Derived Agent Tools")
        }
    }
}
