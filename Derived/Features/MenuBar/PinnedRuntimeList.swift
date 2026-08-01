import SwiftUI

struct PinnedRuntimeList: View {
    let model: AppModel

    private var runtimes: [RuntimeInformation] {
        model.report?.items.compactMap(\.runtime) ?? []
    }

    var body: some View {
        if !runtimes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .padding(.bottom, 8)

                Text("Pinned Simulator Runtimes")
                    .font(.headline)
                    .bold()

                Text("Pin runtimes you want identified as protected during manual cleanup.")
                    .foregroundStyle(.secondary)

                ForEach(runtimes) { runtime in
                    let isPinned = model.settingsStore.settings.pinnedRuntimeIDs.contains(runtime.id)
                    PinnedRuntimeRow(
                        runtime: runtime,
                        isPinned: isPinned,
                        onChange: { model.settingsStore.setPinned($0, runtimeID: runtime.id) }
                    )
                }
            }
            .padding(.top, DesignMetrics.contentSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
