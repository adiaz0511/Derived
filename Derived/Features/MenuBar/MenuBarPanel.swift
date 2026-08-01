import SwiftUI

struct MenuBarPanel: View {
    let model: AppModel
    @State private var cleanupRequest: CleanupRequest?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DesignMetrics.contentSpacing) {
                        Color.clear
                            .frame(height: 0)
                            .id(PanelScrollTarget.top)

                        StorageSummaryCard(snapshot: model.storageSnapshot)

                        PanelStatusBanner(report: model.report)

                        ForEach(CleanupCategory.allCases) { category in
                            CleanupCategoryCard(
                                category: category,
                                model: model,
                                onDelete: requestCleanup
                            )
                        }

                        AutomaticCleanupCard(model: model)
                        CleanupPreferencesCard(model: model)
                        DeleteSelectionCard(model: model, onDelete: requestCleanup)

                        Color.clear
                            .frame(height: 0)
                            .id(PanelScrollTarget.bottom)
                    }
                    .padding()
                }
                #if DEBUG
                .onReceive(NotificationCenter.default.publisher(for: .panelStressScroll)) { notification in
                    applyStressScroll(notification, proxy: proxy)
                }
                #endif
            }

            Divider()
            PanelFooter(model: model)
        }
        .frame(width: DesignMetrics.panelWidth, height: DesignMetrics.panelHeight)
        .background(.ultraThinMaterial)
        .cleanupExecution(model: model, request: $cleanupRequest)
        .task {
            guard model.report == nil else { return }
            await model.scan()
        }
    }

    private func requestCleanup(_ scope: CleanupSelectionScope) {
        let items = model.cleanupItems(for: scope)
        guard !items.isEmpty, !model.isCleaning else { return }
        cleanupRequest = CleanupRequest(
            scope: scope,
            preview: model.cleanupPreview(for: items)
        )
    }

    #if DEBUG
    private func applyStressScroll(_ notification: Notification, proxy: ScrollViewProxy) {
        guard let rawTarget = notification.userInfo?["target"] as? String,
              let target = PanelScrollTarget(rawValue: rawTarget) else { return }
        proxy.scrollTo(target, anchor: target == .top ? .top : .bottom)
    }
    #endif
}
