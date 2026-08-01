import SwiftUI

struct CleanupPreferencesCard: View {
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

                        Label("Cleanup Preferences", systemImage: "slider.horizontal.3")
                            .bold()
                    }
                    .font(.headline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse Cleanup Preferences" : "Expand Cleanup Preferences")

                SectionInfoButton(
                    title: "Cleanup Preferences",
                    message: "Controls Device Support preselection and identifies simulator runtimes you want to protect during manual cleanup."
                )

                Spacer()
            }

            if isExpanded {
                CleanupPreferencesContent(model: model)
                    .transition(.opacity)
            }
        }
        .panelCard()
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .panelStressPreferencesDisclosure)) { notification in
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
