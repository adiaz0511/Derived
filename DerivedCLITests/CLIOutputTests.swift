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
        #expect(DerivedAgentVersion.cliDescription == "derived 1.0.4")
    }

    @Test func cleanupPlanExplainsConfirmationAndPrintsDeleteCommand() {
        let planID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let plan = AgentCleanupPlan(
            schemaVersion: 1,
            planID: planID,
            scanID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 0),
            expiresAt: Date(timeIntervalSince1970: 600),
            itemCount: 2,
            verifiedReclaimableBytes: 120_803_328,
            logicalBytes: 0,
            categories: [.previewData],
            requiresAdditionalConfirmation: false,
            confirmationPhrase: "DELETE 2 ITEMS"
        )

        let output = CLIOutput.plan(plan)

        #expect(output.contains("Confirmation phrase: DELETE 2 ITEMS"))
        #expect(output.contains("To permanently delete these items within 10 minutes, run:"))
        #expect(output.contains("derived delete --plan \(planID.uuidString) --confirm 'DELETE 2 ITEMS'"))
    }
}
