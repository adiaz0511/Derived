import SwiftUI

struct CleanupExecutionModifier: ViewModifier {
    let model: AppModel
    @Binding var request: CleanupRequest?
    @State private var report: CleanupReport?
    @State private var isShowingConfirmation = false
    @State private var isShowingBlockedAlert = false
    @State private var blockedMessage = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id, prepareCleanup)
            .alert(
                confirmationTitle,
                isPresented: $isShowingConfirmation
            ) {
                Button("Delete", role: .destructive, action: confirmCleanup)
                Button("Cancel", role: .cancel, action: cancelCleanup)
            } message: {
                Text(confirmationMessage)
            }
            .alert("Cleanup Blocked", isPresented: $isShowingBlockedAlert) {
                Button("OK", role: .cancel, action: cancelCleanup)
            } message: {
                Text(blockedMessage)
            }
            .sheet(item: $report) { report in
                CleanupReportView(report: report, onClose: closeReport)
                    .frame(width: 520, height: 620)
            }
    }

    private var confirmationTitle: String {
        guard let request else { return "Delete Items?" }
        switch request.scope {
        case .allItems(let category):
            return "Delete All \(category.title)?"
        case .selectedItems(let category):
            return "Delete Selected \(category.title)?"
        case .selectedItemsAcrossAllCategories:
            return "Delete All Selected Items?"
        }
    }

    private var confirmationMessage: String {
        "This permanently deletes the selected files, simulator devices, and runtimes. This action cannot be undone."
    }

    private func prepareCleanup() {
        guard let request else { return }
        let requestID = request.id
        Task {
            let currentPreflight = await model.cleanupPreflight(for: request.preview)
            guard self.request?.id == requestID else { return }

            if currentPreflight.hasInvalidTargets {
                blockedMessage = "One or more targets no longer pass allowlist validation. Rescan before trying again. Nothing was deleted."
                isShowingBlockedAlert = true
            } else {
                isShowingConfirmation = true
            }
        }
    }

    private func confirmCleanup() {
        performCleanup(highRiskConfirmed: true)
    }

    private func performCleanup(highRiskConfirmed: Bool) {
        guard let request else { return }
        Task {
            report = await model.executeCleanup(
                preview: request.preview,
                highRiskConfirmed: highRiskConfirmed
            )
            self.request = nil
        }
    }

    private func cancelCleanup() {
        request = nil
    }

    private func closeReport() {
        report = nil
    }
}

extension View {
    func cleanupExecution(model: AppModel, request: Binding<CleanupRequest?>) -> some View {
        modifier(CleanupExecutionModifier(model: model, request: request))
    }
}
