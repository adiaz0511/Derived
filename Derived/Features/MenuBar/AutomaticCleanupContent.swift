import SwiftUI

struct AutomaticCleanupContent: View {
    let model: AppModel
    @Bindable private var store: SettingsStore

    init(model: AppModel) {
        self.model = model
        store = model.settingsStore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignMetrics.contentSpacing) {
            ForEach(CleanupAutomationCategory.allCases) { category in
                AutomaticCleanupRuleRow(
                    category: category,
                    rule: store.automationRule(for: category),
                    onSetEnabled: { store.setAutomationEnabled($0, category: category) },
                    onSetFrequency: { store.setAutomationFrequency($0, category: category) }
                )
            }

            automationStatus
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var automationStatus: some View {
        switch model.automationStatus {
        case .deferred(let activeProcesses):
            Label(
                "Cleanup deferred while active: \(activeProcesses.joined(separator: ", "))",
                systemImage: "pause.circle"
            )
            .foregroundStyle(.orange)
        case .completed(let date):
            Label(
                "Automatic cleanup completed \(date.formatted(date: .omitted, time: .shortened)).",
                systemImage: "checkmark.circle"
            )
            .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        case nil:
            EmptyView()
        }
    }
}
