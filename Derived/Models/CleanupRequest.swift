import Foundation

nonisolated struct CleanupRequest: Identifiable, Sendable {
    let id = UUID()
    let scope: CleanupSelectionScope
    let preview: DryRunPreview
}
