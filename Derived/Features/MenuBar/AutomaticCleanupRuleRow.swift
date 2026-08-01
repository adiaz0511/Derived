import SwiftUI

struct AutomaticCleanupRuleRow: View {
    let category: CleanupAutomationCategory
    let rule: CleanupAutomationRule
    let onSetEnabled: (Bool) -> Void
    let onSetFrequency: (CleanupFrequency) -> Void
    @State private var isShowingEnableConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: DesignMetrics.sectionTitleIconSpacing) {
                        Image(systemName: category.symbolName)
                            .frame(width: DesignMetrics.sectionTitleIconWidth)
                            .accessibilityHidden(true)

                        Text(category.title)
                            .bold()
                    }

                    HStack(spacing: 8) {
                        Text("Every")
                            .foregroundStyle(.secondary)

                        Picker("Frequency", selection: frequencyBinding) {
                            ForEach(CleanupFrequency.allCases) { frequency in
                                Text(frequency.menuTitle).tag(frequency)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                }

                Spacer()

                Toggle("Automatically delete all \(category.title)", isOn: enabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if rule.isEnabled {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lastRunDescription)
                    if let nextRunDate = rule.nextRunDate() {
                        Text("Next cleanup: \(nextRunDate.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .alert(
            "Enable Automatic \(category.title) Cleanup?",
            isPresented: $isShowingEnableConfirmation
        ) {
            Button("Enable Automation", role: .destructive) {
                onSetEnabled(true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Derived will permanently delete all \(category.title) every \(rule.frequency.intervalDescription) when it is due. It runs only while this app is open and development tools are closed.")
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { rule.isEnabled },
            set: { requestedValue in
                if requestedValue {
                    isShowingEnableConfirmation = true
                } else {
                    onSetEnabled(false)
                }
            }
        )
    }

    private var frequencyBinding: Binding<CleanupFrequency> {
        Binding(get: { rule.frequency }, set: onSetFrequency)
    }

    private var lastRunDescription: String {
        guard let lastRunAt = rule.lastRunAt else {
            return "Last cleanup: Not yet run"
        }
        return "Last cleanup: \(lastRunAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
