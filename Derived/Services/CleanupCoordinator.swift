import Foundation

actor CleanupCoordinator {
    private let validator: PathValidator
    private let commandBuilder: CleanupCommandBuilder
    private let runner: any CommandRunning
    private let fileRemover: any FileRemoving
    private let processMonitor: ProcessMonitor
    private let historyStore: any CleanupHistoryStoring

    init(
        validator: PathValidator = PathValidator(),
        commandBuilder: CleanupCommandBuilder = CleanupCommandBuilder(),
        runner: any CommandRunning = FoundationCommandRunner(),
        fileRemover: any FileRemoving = FoundationFileRemover(),
        processMonitor: ProcessMonitor = ProcessMonitor(),
        historyStore: any CleanupHistoryStoring = CleanupHistoryStore()
    ) {
        self.validator = validator
        self.commandBuilder = commandBuilder
        self.runner = runner
        self.fileRemover = fileRemover
        self.processMonitor = processMonitor
        self.historyStore = historyStore
    }

    func preflight(items: [CleanupItem], pinnedRuntimeIDs: Set<String>) async -> CleanupPreflight {
        var validations: [String: PathValidationResult] = [:]
        for item in items {
            validations[item.id] = validator.validate(item)
        }
        let activeProcesses = await processMonitor.activeRelatedProcesses()
        let highRiskItemIDs = Set<String>(items.compactMap { item -> String? in
            guard !item.isActive else { return nil }
            let isPinned = item.runtime.map { pinnedRuntimeIDs.contains($0.id) } == true
            let isNewestRuntime = item.runtime?.isNewestForPlatform == true
            let requiresConfirmation = item.safety == .highRisk || isPinned || isNewestRuntime
            return requiresConfirmation ? item.id : nil
        })
        return CleanupPreflight(
            validations: validations,
            activeProcesses: activeProcesses,
            highRiskItemIDs: highRiskItemIDs
        )
    }

    func execute(
        items: [CleanupItem],
        pinnedRuntimeIDs: Set<String>,
        highRiskConfirmed: Bool,
        blockWhenRelatedProcessesAreActive: Bool = false,
        trigger: CleanupTrigger = .manual
    ) async -> CleanupReport {
        let startedAt = Date.now
        let preflight = await preflight(items: items, pinnedRuntimeIDs: pinnedRuntimeIDs)

        if preflight.hasInvalidTargets {
            return await finishReport(
                trigger: trigger,
                startedAt: startedAt,
                results: items.map { blockedResult(for: $0, message: preflight.validations[$0.id]?.message ?? "Validation failed.") },
                activeProcesses: preflight.activeProcesses
            )
        }

        if blockWhenRelatedProcessesAreActive {
            let inspection = await processMonitor.inspectRelatedProcesses()
            let blockMessage: String?
            let activeProcesses: [String]
            switch inspection {
            case .available(let processes) where !processes.isEmpty:
                blockMessage = "Automatic cleanup was deferred because development tools are active."
                activeProcesses = processes
            case .available:
                blockMessage = nil
                activeProcesses = []
            case .unavailable:
                blockMessage = "Automatic cleanup was deferred because active development tools could not be verified."
                activeProcesses = []
            }

            if let blockMessage {
                return await finishReport(
                    trigger: trigger,
                    startedAt: startedAt,
                    results: items.map { blockedResult(for: $0, message: blockMessage) },
                    activeProcesses: activeProcesses
                )
            }
        }

        if preflight.requiresHighRiskConfirmation && !highRiskConfirmed {
            return await finishReport(
                trigger: trigger,
                startedAt: startedAt,
                results: items.map { blockedResult(for: $0, message: "The required high-risk confirmation was not provided.") },
                activeProcesses: preflight.activeProcesses
            )
        }

        var results: [CleanupItemResult] = []
        for item in items {
            if item.isActive {
                results.append(blockedResult(for: item, message: "The target is currently active. Shut it down, rescan, and try again."))
                continue
            }

            let validation = validator.validate(item)
            guard validation.isValid else {
                results.append(blockedResult(for: item, message: validation.message))
                continue
            }

            results.append(await execute(item))
        }

        return await finishReport(
            trigger: trigger,
            startedAt: startedAt,
            results: results,
            activeProcesses: preflight.activeProcesses
        )
    }

    private func execute(_ item: CleanupItem) async -> CleanupItemResult {
        switch item.removalMethod {
        case .fileSystem:
            let operation = "Permanently delete: \(item.path)"
            do {
                try await fileRemover.removeItem(at: URL(filePath: item.path))
                return result(for: item, outcome: .removed, operation: operation, message: "Permanently deleted.")
            } catch {
                return result(for: item, outcome: .failed, operation: operation, message: error.localizedDescription)
            }

        case .simulatorDevice, .simulatorRuntime:
            guard let command = commandBuilder.command(for: item) else {
                return result(for: item, outcome: .blocked, operation: "No operation", message: "No supported removal command is available.")
            }
            let operation = ([command.executable] + command.arguments).joined(separator: " ")
            do {
                let commandResult = try await runner.run(executable: command.executable, arguments: command.arguments)
                if commandResult.succeeded {
                    let message = commandResult.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    return result(
                        for: item,
                        outcome: .removed,
                        operation: operation,
                        message: message.isEmpty ? "Removed using simctl." : message
                    )
                }
                let message = commandResult.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
                return result(
                    for: item,
                    outcome: .failed,
                    operation: operation,
                    message: message.isEmpty ? "simctl exited with status \(commandResult.exitCode)." : message
                )
            } catch {
                return result(for: item, outcome: .failed, operation: operation, message: error.localizedDescription)
            }
        }
    }

    private func finishReport(
        trigger: CleanupTrigger,
        startedAt: Date,
        results: [CleanupItemResult],
        activeProcesses: [String]
    ) async -> CleanupReport {
        var report = CleanupReport(
            id: UUID(),
            trigger: trigger,
            startedAt: startedAt,
            completedAt: .now,
            results: results,
            activeProcesses: activeProcesses,
            historyError: nil
        )
        do {
            try await historyStore.append(report)
        } catch {
            report.historyError = error.localizedDescription
        }
        return report
    }

    private func result(
        for item: CleanupItem,
        outcome: CleanupOutcome,
        operation: String,
        message: String
    ) -> CleanupItemResult {
        CleanupItemResult(
            itemID: item.id,
            name: item.name,
            category: item.category,
            path: item.path,
            byteCount: item.verifiedReclaimableBytes,
            logicalByteCount: item.sizeClassification == .apfsCloneLogical ? item.byteCount : nil,
            outcome: outcome,
            operation: operation,
            message: message
        )
    }

    private func blockedResult(for item: CleanupItem, message: String) -> CleanupItemResult {
        result(for: item, outcome: .blocked, operation: "Blocked before execution", message: message)
    }
}
