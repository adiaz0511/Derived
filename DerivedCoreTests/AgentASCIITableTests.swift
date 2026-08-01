@testable import DerivedCore
import Testing

struct AgentASCIITableTests {
    @Test func rendersAlignedASCIIColumns() {
        let table = AgentASCIITable.render(
            columns: [
                AgentTableColumn("Category"),
                AgentTableColumn("Items", alignment: .trailing)
            ],
            rows: [
                ["Derived Data", "7"],
                ["Caches", "12"]
            ]
        )

        #expect(table.contains("| Category     | Items |"))
        #expect(table.contains("| Derived Data |     7 |"))
        #expect(table.contains("| Caches       |    12 |"))
        #expect(table.hasPrefix("+"))
        #expect(table.hasSuffix("+"))
    }

    @Test func clipsLongValuesToConfiguredWidth() {
        let table = AgentASCIITable.render(
            columns: [AgentTableColumn("Name", maximumWidth: 10)],
            rows: [["A very long candidate name"]]
        )

        #expect(table.contains("A very ..."))
        #expect(!table.contains("candidate"))
    }
}
