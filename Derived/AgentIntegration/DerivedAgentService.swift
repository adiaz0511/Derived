import Foundation

public actor DerivedAgentService {
    public static let schemaVersion = 1
    public static let maximumPageSize = 50

    private let engine: any AgentCleanupEngine
    private let stateStore: AgentStateStore
    private let scanLifetime: TimeInterval
    private let planLifetime: TimeInterval
    private let now: @Sendable () -> Date

    public init() {
        engine = LiveAgentCleanupEngine()
        stateStore = AgentStateStore()
        scanLifetime = 30 * 60
        planLifetime = 10 * 60
        now = { .now }
    }

    init(
        engine: any AgentCleanupEngine,
        stateStore: AgentStateStore,
        scanLifetime: TimeInterval = 30 * 60,
        planLifetime: TimeInterval = 10 * 60,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.engine = engine
        self.stateStore = stateStore
        self.scanLifetime = scanLifetime
        self.planLifetime = planLifetime
        self.now = now
    }

    public func scan() async throws -> AgentScan {
        let currentDate = now()
        try await stateStore.removeExpired(before: currentDate)
        let result = await engine.scan()
        let identifier = UUID()
        let expiration = currentDate.addingTimeInterval(scanLifetime)
        let stored = StoredAgentScan(
            id: identifier,
            scannedAt: result.scannedAt,
            expiresAt: expiration,
            items: result.items,
            activeProcesses: result.activeProcesses,
            warnings: result.warnings,
            pinnedRuntimeIDs: result.pinnedRuntimeIDs
        )
        try await stateStore.save(scan: stored)
        return makeScan(from: stored)
    }

    public func listCandidates(
        scanID: UUID,
        category: AgentCategory,
        offset: Int = 0,
        limit: Int = 20
    ) async throws -> AgentCandidatePage {
        guard (1...Self.maximumPageSize).contains(limit), offset >= 0 else {
            throw AgentIntegrationError.invalidLimit
        }
        let scan = try await loadScan(id: scanID)
        let matching = scan.items.filter { $0.category == category.cleanupCategory }
        let lowerBound = min(offset, matching.count)
        let upperBound = min(lowerBound + limit, matching.count)
        let candidates = matching[lowerBound..<upperBound].map {
            AgentCandidate(item: $0, pinnedRuntimeIDs: scan.pinnedRuntimeIDs)
        }
        return AgentCandidatePage(
            schemaVersion: Self.schemaVersion,
            scanID: scanID,
            category: category,
            candidates: candidates,
            offset: lowerBound,
            limit: limit,
            totalCount: matching.count,
            nextOffset: upperBound < matching.count ? upperBound : nil
        )
    }

    public func prepareCleanup(
        scanID: UUID,
        selection: AgentCleanupSelection
    ) async throws -> AgentCleanupPlan {
        let scan = try await loadScan(id: scanID)
        let requestedIDs = Set(selection.itemIDs)
        let availableIDs = Set(scan.items.map(\.id))
        let missingIDs = requestedIDs.subtracting(availableIDs).sorted()
        guard missingIDs.isEmpty else {
            throw AgentIntegrationError.missingCandidates(missingIDs)
        }

        let requestedCategories = Set(selection.categories.map(\.cleanupCategory))
        let selectedItems = scan.items.filter {
            requestedIDs.contains($0.id) || requestedCategories.contains($0.category)
        }
        guard !selectedItems.isEmpty else {
            throw AgentIntegrationError.noCandidatesSelected
        }

        let currentDate = now()
        let requiresAdditionalConfirmation = selectedItems.contains {
            AgentCandidate(item: $0, pinnedRuntimeIDs: scan.pinnedRuntimeIDs).requiresAdditionalConfirmation
        }
        let confirmationPhrase = requiresAdditionalConfirmation
            ? "DELETE \(selectedItems.count) ITEMS INCLUDING HIGH RISK"
            : "DELETE \(selectedItems.count) ITEMS"
        let stored = StoredAgentPlan(
            id: UUID(),
            scanID: scanID,
            createdAt: currentDate,
            expiresAt: currentDate.addingTimeInterval(planLifetime),
            items: selectedItems,
            pinnedRuntimeIDs: scan.pinnedRuntimeIDs,
            confirmationPhrase: confirmationPhrase,
            requiresAdditionalConfirmation: requiresAdditionalConfirmation
        )
        try await stateStore.save(plan: stored)
        return makePlan(from: stored)
    }

    public func executeCleanup(planID: UUID, confirmationPhrase: String) async throws -> AgentCleanupResult {
        guard let plan = try await stateStore.loadPlan(id: planID) else {
            throw AgentIntegrationError.planNotFound
        }
        guard plan.expiresAt > now() else {
            try await stateStore.removePlan(id: planID)
            throw AgentIntegrationError.planExpired
        }
        guard confirmationPhrase == plan.confirmationPhrase else {
            throw AgentIntegrationError.invalidConfirmation
        }

        let currentScan = await engine.scan()
        let currentItems = currentScan.items.reduce(into: [String: CleanupItem]()) { result, item in
            result[item.id] = item
        }
        let staleIDs = plan.items.compactMap { expected -> String? in
            guard let current = currentItems[expected.id], candidateIdentity(current) == candidateIdentity(expected) else {
                return expected.id
            }
            return nil
        }
        guard staleIDs.isEmpty else {
            try await stateStore.removePlan(id: planID)
            throw AgentIntegrationError.staleCandidates(staleIDs)
        }

        try await stateStore.removePlan(id: planID)
        let items = plan.items.compactMap { currentItems[$0.id] }
        let report = await engine.delete(
            items: items,
            highRiskConfirmed: plan.requiresAdditionalConfirmation
        )
        return AgentCleanupResult(
            schemaVersion: Self.schemaVersion,
            planID: planID,
            completedAt: report.completedAt,
            permanentlyRemovedBytes: report.permanentlyRemovedBytes,
            failureCount: report.failureCount,
            blockedCount: report.blockedCount,
            items: report.results.map {
                AgentCleanupItemResult(
                    itemID: $0.itemID,
                    name: $0.name,
                    category: AgentCategory($0.category),
                    byteCount: $0.byteCount,
                    outcome: $0.outcome.rawValue,
                    message: $0.message
                )
            },
            historyError: report.historyError
        )
    }

    private func loadScan(id: UUID) async throws -> StoredAgentScan {
        guard let scan = try await stateStore.loadScan(id: id) else {
            throw AgentIntegrationError.scanNotFound
        }
        guard scan.expiresAt > now() else {
            throw AgentIntegrationError.scanExpired
        }
        return scan
    }

    private func makeScan(from scan: StoredAgentScan) -> AgentScan {
        let categories = AgentCategory.allCases.compactMap { category -> AgentCategorySummary? in
            let items = scan.items.filter { $0.category == category.cleanupCategory }
            guard !items.isEmpty else { return nil }
            return AgentCategorySummary(
                category: category,
                itemCount: items.count,
                verifiedReclaimableBytes: items.reduce(0) { $0 + $1.verifiedReclaimableBytes },
                logicalBytes: items.filter { $0.sizeClassification == .apfsCloneLogical }.reduce(0) { $0 + $1.byteCount },
                recommendedItemCount: items.count(where: \.isRecommended)
            )
        }
        return AgentScan(
            schemaVersion: Self.schemaVersion,
            scanID: scan.id,
            scannedAt: scan.scannedAt,
            expiresAt: scan.expiresAt,
            categories: categories,
            activeProcesses: scan.activeProcesses,
            warnings: scan.warnings
        )
    }

    private func makePlan(from plan: StoredAgentPlan) -> AgentCleanupPlan {
        AgentCleanupPlan(
            schemaVersion: Self.schemaVersion,
            planID: plan.id,
            scanID: plan.scanID,
            createdAt: plan.createdAt,
            expiresAt: plan.expiresAt,
            itemCount: plan.items.count,
            verifiedReclaimableBytes: plan.items.reduce(0) { $0 + $1.verifiedReclaimableBytes },
            logicalBytes: plan.items.filter { $0.sizeClassification == .apfsCloneLogical }.reduce(0) { $0 + $1.byteCount },
            categories: Array(Set(plan.items.map { AgentCategory($0.category) })).sorted { $0.rawValue < $1.rawValue },
            requiresAdditionalConfirmation: plan.requiresAdditionalConfirmation,
            confirmationPhrase: plan.confirmationPhrase
        )
    }

    private func candidateIdentity(_ item: CleanupItem) -> String {
        [
            item.id,
            item.category.rawValue,
            item.path,
            String(item.byteCount),
            item.modifiedAt?.timeIntervalSince1970.description ?? "",
            String(item.isActive)
        ].joined(separator: "|")
    }
}
