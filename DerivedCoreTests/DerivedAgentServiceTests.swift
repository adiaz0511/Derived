@testable import DerivedCore
import Foundation
import Testing

struct DerivedAgentServiceTests {
    @Test func scanSeparatesVerifiedAndLogicalBytes() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let items = [
            AgentTestFixtures.item(id: "derived", category: .derivedData, byteCount: 2_048),
            AgentTestFixtures.item(id: "clone", category: .xctestDevices, byteCount: 9_000, logicalSize: true)
        ]
        let (service, _) = AgentTestFixtures.service(scans: [AgentTestFixtures.scan(items: items)], root: root)

        let scan = try await service.scan()
        let derived = try #require(scan.categories.first { $0.category == .derivedData })
        let xctest = try #require(scan.categories.first { $0.category == .xctestDevices })

        #expect(scan.schemaVersion == 1)
        #expect(derived.verifiedReclaimableBytes == 2_048)
        #expect(xctest.verifiedReclaimableBytes == 0)
        #expect(xctest.logicalBytes == 9_000)
    }

    @Test func candidateListsArePaginatedWithoutNestedOrUnboundedResults() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let items = (0..<23).map {
            AgentTestFixtures.item(id: "xctest-\($0)", category: .xctestDevices)
        }
        let (service, _) = AgentTestFixtures.service(scans: [AgentTestFixtures.scan(items: items)], root: root)
        let scan = try await service.scan()

        let firstPage = try await service.listCandidates(scanID: scan.scanID, category: .xctestDevices, limit: 10)
        let secondPage = try await service.listCandidates(
            scanID: scan.scanID,
            category: .xctestDevices,
            offset: try #require(firstPage.nextOffset),
            limit: 10
        )

        #expect(firstPage.candidates.count == 10)
        #expect(firstPage.totalCount == 23)
        #expect(firstPage.nextOffset == 10)
        #expect(secondPage.offset == 10)
        #expect(secondPage.nextOffset == 20)
    }

    @Test func categoryPlanCannotIncludeSelectionsFromAnotherCategory() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let items = [
            AgentTestFixtures.item(id: "derived", category: .derivedData),
            AgentTestFixtures.item(id: "archive", category: .archives, safety: .highRisk, recommended: false)
        ]
        let (service, _) = AgentTestFixtures.service(scans: [AgentTestFixtures.scan(items: items)], root: root)
        let scan = try await service.scan()

        let plan = try await service.prepareCleanup(
            scanID: scan.scanID,
            selection: AgentCleanupSelection(categories: [.derivedData])
        )

        #expect(plan.itemCount == 1)
        #expect(plan.categories == [.derivedData])
        #expect(!plan.requiresAdditionalConfirmation)
    }

    @Test func deletionRequiresExactConfirmationAndPlanCannotBeReplayed() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let item = AgentTestFixtures.item(id: "derived", category: .derivedData)
        let scanResult = AgentTestFixtures.scan(items: [item])
        let (service, engine) = AgentTestFixtures.service(scans: [scanResult, scanResult], root: root)
        let scan = try await service.scan()
        let plan = try await service.prepareCleanup(
            scanID: scan.scanID,
            selection: AgentCleanupSelection(itemIDs: [item.id])
        )

        await #expect(throws: AgentIntegrationError.self) {
            try await service.executeCleanup(planID: plan.planID, confirmationPhrase: "yes")
        }
        #expect(await engine.deletedItemIDs.isEmpty)

        let result = try await service.executeCleanup(
            planID: plan.planID,
            confirmationPhrase: plan.confirmationPhrase
        )
        #expect(result.items.map(\.itemID) == [item.id])
        #expect(await engine.deletedItemIDs == [item.id])

        await #expect(throws: AgentIntegrationError.self) {
            try await service.executeCleanup(
                planID: plan.planID,
                confirmationPhrase: plan.confirmationPhrase
            )
        }
    }

    @Test func deletionFailsClosedWhenCandidateChangesAfterPlanning() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = AgentTestFixtures.item(id: "derived", category: .derivedData, byteCount: 1_024)
        let changed = AgentTestFixtures.item(id: "derived", category: .derivedData, byteCount: 2_048)
        let (service, engine) = AgentTestFixtures.service(
            scans: [AgentTestFixtures.scan(items: [original]), AgentTestFixtures.scan(items: [changed])],
            root: root
        )
        let scan = try await service.scan()
        let plan = try await service.prepareCleanup(
            scanID: scan.scanID,
            selection: AgentCleanupSelection(itemIDs: [original.id])
        )

        await #expect(throws: AgentIntegrationError.self) {
            try await service.executeCleanup(
                planID: plan.planID,
                confirmationPhrase: plan.confirmationPhrase
            )
        }
        #expect(await engine.deletedItemIDs.isEmpty)
    }

    @Test func highRiskPlanUsesAnExplicitHighRiskPhrase() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let item = AgentTestFixtures.item(
            id: "archive",
            category: .archives,
            safety: .highRisk,
            recommended: false
        )
        let (service, _) = AgentTestFixtures.service(
            scans: [AgentTestFixtures.scan(items: [item])],
            root: root
        )
        let scan = try await service.scan()
        let plan = try await service.prepareCleanup(
            scanID: scan.scanID,
            selection: AgentCleanupSelection(itemIDs: [item.id])
        )

        #expect(plan.requiresAdditionalConfirmation)
        #expect(plan.confirmationPhrase.contains("INCLUDING HIGH RISK"))
    }

    private func temporaryDirectory() -> URL {
        URL.temporaryDirectory.appending(path: "DerivedCoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }
}
