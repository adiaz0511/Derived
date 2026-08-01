import SwiftUI

struct AutomaticCleanupCard: View {
    let model: AppModel
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: toggleExpanded) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))

                        Label("Automatic Cleanup", systemImage: "clock.arrow.2.circlepath")
                            .bold()
                    }
                    .font(.headline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse Automatic Cleanup" : "Expand Automatic Cleanup")

                SectionInfoButton(
                    title: "Automatic Cleanup",
                    message: "Permanently deletes all Derived Data, Xcode Logs, or Xcode Caches on the schedules you enable. Cleanup is deferred while development tools are active."
                )

                Spacer()
            }

            if isExpanded {
                AutomaticCleanupContent(model: model)
                    .transition(.opacity)
            }
        }
        .panelCard()
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .panelStressAutomationDisclosure)) { notification in
            applyStressDisclosure(notification)
        }
        #endif
    }

    private func toggleExpanded() {
        withAnimation(disclosureAnimation) {
            isExpanded.toggle()
        }
    }

    private var disclosureAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .smooth(duration: 0.24)
    }

    #if DEBUG
    private func applyStressDisclosure(_ notification: Notification) {
        guard let expanded = notification.userInfo?["isExpanded"] as? Bool else { return }
        withAnimation(disclosureAnimation) {
            isExpanded = expanded
        }
    }
    #endif
}
