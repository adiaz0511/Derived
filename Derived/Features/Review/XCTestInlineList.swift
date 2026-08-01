import SwiftUI

struct XCTestInlineList: View {
    let items: [CleanupItem]
    let model: AppModel
    let onDelete: (CleanupSelectionScope) -> Void
    @State private var pageIndex = 0

    private let pageSize = 10

    private var pageCount: Int {
        max(1, (items.count + pageSize - 1) / pageSize)
    }

    private var pageItems: ArraySlice<CleanupItem> {
        let safePage = min(pageIndex, pageCount - 1)
        let start = min(safePage * pageSize, items.count)
        let end = min(start + pageSize, items.count)
        return items[start..<end]
    }

    private var hasSelectedItems: Bool {
        items.contains { model.selectedItemIDs.contains($0.id) }
    }

    private var selectedBytes: Int64 {
        items.reduce(0) { total, item in
            model.selectedItemIDs.contains(item.id) ? total + item.verifiedReclaimableBytes : total
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                ForEach(pageItems) { item in
                    CleanupCandidateRow(
                        item: item,
                        isSelected: model.selectedItemIDs.contains(item.id),
                        isPinned: false,
                        onSelectionChange: { model.setSelected($0, item: item) },
                        onPinChange: ignorePinChange
                    )
                }
            }

            HStack {
                Button("Previous", systemImage: "chevron.left", action: previousPage)
                    .disabled(pageIndex == 0)

                Spacer()

                Text("Page \(pageIndex + 1) of \(pageCount)")
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Next", systemImage: "chevron.right", action: nextPage)
                    .disabled(pageIndex >= pageCount - 1)
            }

            Button("Delete Selected (\(ByteCountFormat.string(selectedBytes)))", action: deleteSelected)
                .buttonStyle(.borderedProminent)
                .disabled(!hasSelectedItems || model.isCleaning)
        }
        .onChange(of: items.count, resetPage)
    }

    private func previousPage() {
        pageIndex = max(0, pageIndex - 1)
    }

    private func nextPage() {
        pageIndex = min(pageCount - 1, pageIndex + 1)
    }

    private func resetPage() {
        pageIndex = 0
    }

    private func deleteSelected() {
        onDelete(.selectedItems(in: .xctestDevices))
    }

    private func ignorePinChange(runtimeID _: String, isPinned _: Bool) {}
}
