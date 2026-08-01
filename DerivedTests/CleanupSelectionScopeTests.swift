import Foundation
import Testing
@testable import Derived

struct CleanupSelectionScopeTests {
    @Test func sectionSelectionExcludesSelectionsFromOtherSections() {
        let xctest = fixture(id: "xctest", category: .xctestDevices)
        let derived = fixture(id: "derived", category: .derivedData)

        let result = CleanupSelectionScope.selectedItems(in: .xctestDevices).resolve(
            from: [xctest, derived],
            selectedItemIDs: [xctest.id, derived.id]
        )

        #expect(result.map(\.id) == [xctest.id])
    }

    @Test func sectionDeleteAllExcludesOtherSections() {
        let firstXCTest = fixture(id: "xctest-1", category: .xctestDevices)
        let secondXCTest = fixture(id: "xctest-2", category: .xctestDevices)
        let derived = fixture(id: "derived", category: .derivedData)

        let result = CleanupSelectionScope.allItems(in: .xctestDevices).resolve(
            from: [firstXCTest, derived, secondXCTest],
            selectedItemIDs: [derived.id]
        )

        #expect(result.map(\.id) == [firstXCTest.id, secondXCTest.id])
    }

    @Test func globalSelectionIncludesSelectionsFromEverySection() {
        let xctest = fixture(id: "xctest", category: .xctestDevices)
        let derived = fixture(id: "derived", category: .derivedData)
        let archive = fixture(id: "archive", category: .archives)

        let result = CleanupSelectionScope.selectedItemsAcrossAllCategories.resolve(
            from: [xctest, derived, archive],
            selectedItemIDs: [xctest.id, archive.id]
        )

        #expect(result.map(\.id) == [xctest.id, archive.id])
    }

    private func fixture(id: String, category: CleanupCategory) -> CleanupItem {
        CleanupItem(
            id: id,
            name: id,
            category: category,
            byteCount: 1_024,
            path: "/tmp/\(id)",
            modifiedAt: nil,
            safety: .recommended,
            reason: "Test",
            isRecommended: true,
            removalMethod: .fileSystem,
            runtime: nil,
            isActive: false
        )
    }
}
