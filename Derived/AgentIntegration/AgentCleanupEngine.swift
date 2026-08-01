import Foundation

nonisolated struct AgentEngineScan: Sendable {
    let scannedAt: Date
    let items: [CleanupItem]
    let activeProcesses: [String]
    let warnings: [String]
    let pinnedRuntimeIDs: Set<String>
}

nonisolated protocol AgentCleanupEngine: Sendable {
    func scan() async -> AgentEngineScan
    func delete(items: [CleanupItem], highRiskConfirmed: Bool) async -> CleanupReport
}

actor LiveAgentCleanupEngine: AgentCleanupEngine {
    private let fileSystemScanner: FileSystemScanner
    private let simulatorScanner: CoreSimulatorScanner
    private let xctestScanner: XCTestScanner
    private let processMonitor: ProcessMonitor
    private let cleanupCoordinator: CleanupCoordinator
    private let defaults: UserDefaults

    init(
        fileSystemScanner: FileSystemScanner = FileSystemScanner(),
        simulatorScanner: CoreSimulatorScanner = CoreSimulatorScanner(),
        xctestScanner: XCTestScanner = XCTestScanner(),
        processMonitor: ProcessMonitor = ProcessMonitor(),
        cleanupCoordinator: CleanupCoordinator? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.fileSystemScanner = fileSystemScanner
        self.simulatorScanner = simulatorScanner
        self.xctestScanner = xctestScanner
        self.processMonitor = processMonitor
        self.cleanupCoordinator = cleanupCoordinator ?? CleanupCoordinator(processMonitor: processMonitor)
        self.defaults = defaults
    }

    func scan() async -> AgentEngineScan {
        let settings = loadSettings()
        async let fileSystemTask = fileSystemScanner.scan(settings: settings)
        async let simulatorTask = simulatorScanner.scan(pinnedRuntimeIDs: settings.pinnedRuntimeIDs)
        async let xctestTask = xctestScanner.scan()
        async let processTask = processMonitor.activeRelatedProcesses()

        let (fileSystemResult, simulatorResult, xctestResult, activeProcesses) = await (
            fileSystemTask,
            simulatorTask,
            xctestTask,
            processTask
        )
        let items = (fileSystemResult.items + simulatorResult.items + xctestResult.items).sorted {
            if $0.category == $1.category { return $0.byteCount > $1.byteCount }
            return $0.category.rawValue < $1.category.rawValue
        }
        return AgentEngineScan(
            scannedAt: .now,
            items: items,
            activeProcesses: activeProcesses,
            warnings: fileSystemResult.warnings + simulatorResult.warnings + xctestResult.warnings,
            pinnedRuntimeIDs: settings.pinnedRuntimeIDs
        )
    }

    func delete(items: [CleanupItem], highRiskConfirmed: Bool) async -> CleanupReport {
        let settings = loadSettings()
        return await cleanupCoordinator.execute(
            items: items,
            pinnedRuntimeIDs: settings.pinnedRuntimeIDs,
            highRiskConfirmed: highRiskConfirmed,
            blockWhenRelatedProcessesAreActive: true,
            trigger: .manual
        )
    }

    private func loadSettings() -> CleanupSettings {
        let storedData = defaults.data(forKey: "cleanupSettings")
            ?? defaults.data(forKey: "retentionSettings")
            ?? UserDefaults(suiteName: "mx.devlabs.XcodeClean")?.data(forKey: "retentionSettings")
        guard let storedData,
              let settings = try? JSONDecoder().decode(CleanupSettings.self, from: storedData) else {
            return CleanupSettings()
        }
        return settings
    }
}
