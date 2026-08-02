@testable import DerivedCLI
@testable import DerivedCore
import Foundation
import Testing

struct CLIOutputTests {
    @Test func scanRendersHeadersAlignedRowsAndTotals() {
        let scan = AgentScan(
            schemaVersion: 1,
            scanID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            scannedAt: Date(timeIntervalSince1970: 0),
            expiresAt: Date(timeIntervalSince1970: 1_800),
            categories: [
                AgentCategorySummary(
                    category: .derivedData,
                    itemCount: 7,
                    verifiedReclaimableBytes: 528_805_888,
                    logicalBytes: 0,
                    recommendedItemCount: 7
                ),
                AgentCategorySummary(
                    category: .deviceSupport,
                    itemCount: 2,
                    verifiedReclaimableBytes: 11_834_146_816,
                    logicalBytes: 0,
                    recommendedItemCount: 0
                )
            ],
            activeProcesses: [],
            warnings: []
        )

        let output = CLIOutput.scan(scan)

        #expect(output.contains("| Category"))
        #expect(output.contains("| Recommended | Reclaimable | Logical |"))
        #expect(output.contains("| Derived Data"))
        #expect(output.contains("| Device Support"))
        #expect(output.contains("| Total"))
        #expect(output.contains("| Total          | -             |     9 |           7 |"))
    }

    @Test func versionDescriptionUsesCurrentAgentVersion() {
        #expect(DerivedAgentVersion.cliDescription == "derived 1.0.1")
    }
}
