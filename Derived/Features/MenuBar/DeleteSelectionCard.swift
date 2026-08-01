import SwiftUI

struct DeleteSelectionCard: View {
    let model: AppModel
    let onDelete: (CleanupSelectionScope) -> Void

    private var selectionDescription: String {
        let count = model.selectedItems.count
        if count == 0 {
            return "Select items in one or more sections to delete them together."
        }
        return "\(count) \(count == 1 ? "item" : "items") selected across all sections."
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Delete All Selected Items")
                    .font(.headline)
                    .bold()
                Text(selectionDescription)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Delete All Selected", systemImage: "trash", action: deleteSelected)
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedItemIDs.isEmpty || model.isCleaning)
        }
        .panelCard()
    }

    private func deleteSelected() {
        onDelete(.selectedItemsAcrossAllCategories)
    }
}
