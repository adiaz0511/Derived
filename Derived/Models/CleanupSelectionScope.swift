import Foundation

nonisolated enum CleanupSelectionScope: Equatable, Sendable {
    case allItems(in: CleanupCategory)
    case selectedItems(in: CleanupCategory)
    case selectedItemsAcrossAllCategories

    func resolve(
        from items: [CleanupItem],
        selectedItemIDs: Set<String>
    ) -> [CleanupItem] {
        switch self {
        case .allItems(let category):
            items.filter { $0.category == category }
        case .selectedItems(let category):
            items.filter {
                $0.category == category && selectedItemIDs.contains($0.id)
            }
        case .selectedItemsAcrossAllCategories:
            items.filter { selectedItemIDs.contains($0.id) }
        }
    }
}
