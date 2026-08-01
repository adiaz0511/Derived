import SwiftUI

struct CleanupPreferencesContent: View {
    let model: AppModel
    @Bindable private var store: SettingsStore

    init(model: AppModel) {
        self.model = model
        store = model.settingsStore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignMetrics.contentSpacing) {
            DeviceSupportPreference(
                isEnabled: $store.settings.preselectOldDeviceSupport,
                minimumAgeDays: $store.settings.deviceSupportMinimumAgeDays
            )

            PinnedRuntimeList(model: model)

            Text("Simulator runtimes are never included in automatic cleanup.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
