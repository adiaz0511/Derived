import SwiftUI

struct MenuBarPanel: View {
    let model: AppModel
    let softwareUpdateController: SoftwareUpdateController
    let agentToolsUpdateController: AgentToolsUpdateController
    @State private var cleanupRequest: CleanupRequest?
    @State private var isShowingAgentToolsUpdate = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DesignMetrics.contentSpacing) {
                        Color.clear
                            .frame(height: 0)
                            .id(PanelScrollTarget.top)

                        StorageSummaryCard(snapshot: model.storageSnapshot)

                        AgentToolsUpdateCard(
                            controller: agentToolsUpdateController,
                            showUpdate: showAgentToolsUpdate
                        )

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
            PanelFooter(
                model: model,
                softwareUpdateController: softwareUpdateController,
                agentToolsUpdateController: agentToolsUpdateController,
                showAgentToolsUpdate: showAgentToolsUpdate
            )
        }
        .frame(width: DesignMetrics.panelWidth, height: DesignMetrics.panelHeight)
        .background(.ultraThinMaterial)
        .cleanupExecution(model: model, request: $cleanupRequest)
        .sheet(isPresented: $isShowingAgentToolsUpdate) {
            AgentToolsUpdateView(
                controller: agentToolsUpdateController,
                close: closeAgentToolsUpdate
            )
        }
        .task {
            await agentToolsUpdateController.checkIfNeeded()
            if model.report == nil {
                await model.scan()
            }
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

    private func showAgentToolsUpdate() {
        isShowingAgentToolsUpdate = true
    }

    private func closeAgentToolsUpdate() {
        isShowingAgentToolsUpdate = false
    }

    #if DEBUG
    private func applyStressScroll(_ notification: Notification, proxy: ScrollViewProxy) {
        guard let rawTarget = notification.userInfo?["target"] as? String,
              let target = PanelScrollTarget(rawValue: rawTarget) else { return }
        proxy.scrollTo(target, anchor: target == .top ? .top : .bottom)
    }
    #endif
}
