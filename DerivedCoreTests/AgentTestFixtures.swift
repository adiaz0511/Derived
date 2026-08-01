@testable import DerivedCore
import Foundation

actor FakeAgentCleanupEngine: AgentCleanupEngine {
    private var scans: [AgentEngineScan]
    private(set) var deletedItemIDs: [String] = []

    init(scans: [AgentEngineScan]) {
        self.scans = scans
    }

    func scan() -> AgentEngineScan {
        if scans.count > 1 {
            return scans.removeFirst()
        }
        return scans[0]
    }

    func delete(items: [CleanupItem], highRiskConfirmed: Bool) -> CleanupReport {
        deletedItemIDs = items.map(\.id)
        return CleanupReport(
            id: UUID(),
            trigger: .manual,
            startedAt: .now,
            completedAt: .now,
            results: items.map {
                CleanupItemResult(
                    itemID: $0.id,
                    name: $0.name,
                    category: $0.category,
                    path: $0.path,
                    byteCount: $0.verifiedReclaimableBytes,
                    logicalByteCount: $0.sizeClassification == .apfsCloneLogical ? $0.byteCount : nil,
                    outcome: .removed,
                    operation: "Test deletion",
                    message: highRiskConfirmed ? "Confirmed." : "Removed."
                )
            },
            activeProcesses: [],
            historyError: nil
        )
    }
}

enum AgentTestFixtures {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func item(
        id: String,
        category: CleanupCategory,
        byteCount: Int64 = 1_024,
        safety: SafetyClassification = .recommended,
        recommended: Bool = true,
        logicalSize: Bool = false
    ) -> CleanupItem {
        CleanupItem(
            id: id,
            name: id,
            category: category,
            byteCount: byteCount,
            path: "/tmp/DerivedTests/\(id)",
            modifiedAt: now,
            safety: safety,
            reason: "Test candidate",
            isRecommended: recommended,
            removalMethod: .fileSystem,
            runtime: nil,
            isActive: false,
            sizeClassification: logicalSize ? .apfsCloneLogical : .verified
        )
    }

    static func scan(items: [CleanupItem]) -> AgentEngineScan {
        AgentEngineScan(
            scannedAt: now,
            items: items,
            activeProcesses: [],
            warnings: [],
            pinnedRuntimeIDs: []
        )
    }

    static func service(
        scans: [AgentEngineScan],
        root: URL,
        now: Date = now
    ) -> (DerivedAgentService, FakeAgentCleanupEngine) {
        let engine = FakeAgentCleanupEngine(scans: scans)
        let service = DerivedAgentService(
            engine: engine,
            stateStore: AgentStateStore(root: root),
            now: { now }
        )
        return (service, engine)
    }
}
