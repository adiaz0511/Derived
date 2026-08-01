import Foundation
import Observation

@Observable
final class AppModel {
    enum ScanState: Equatable {
        case idle
        case scanning
        case failed(String)
    }

    var report: ScanReport?
    var storageSnapshot: DiskStorageSnapshot?
    var itemsByCategory: [CleanupCategory: [CleanupItem]] = [:]
    var selectedItemIDs: Set<String> = []
    var scanState: ScanState = .idle
    var isCleaning = false
    var isRunningAutomation = false
    var automationStatus: CleanupAutomationStatus?
    var lastCleanupReport: CleanupReport?

    let settingsStore: SettingsStore
    private let fileSystemScanner: FileSystemScanner
    private let simulatorScanner: CoreSimulatorScanner
    private let xctestScanner: XCTestScanner
    private let processMonitor: ProcessMonitor
    private let diskStorageScanner: DiskStorageScanner
    private let validator: PathValidator
    private let cleanupCoordinator: CleanupCoordinator

    init(
        settingsStore: SettingsStore = SettingsStore(),
        fileSystemScanner: FileSystemScanner = FileSystemScanner(),
        simulatorScanner: CoreSimulatorScanner = CoreSimulatorScanner(),
        xctestScanner: XCTestScanner = XCTestScanner(),
        processMonitor: ProcessMonitor = ProcessMonitor(),
        diskStorageScanner: DiskStorageScanner = DiskStorageScanner(),
        validator: PathValidator = PathValidator(),
        cleanupCoordinator: CleanupCoordinator? = nil
    ) {
        self.settingsStore = settingsStore
        self.fileSystemScanner = fileSystemScanner
        self.simulatorScanner = simulatorScanner
        self.xctestScanner = xctestScanner
        self.processMonitor = processMonitor
        self.diskStorageScanner = diskStorageScanner
        self.validator = validator
        self.cleanupCoordinator = cleanupCoordinator ?? CleanupCoordinator(
            validator: validator,
            processMonitor: processMonitor
        )
    }

    var isScanning: Bool { scanState == .scanning }

    var selectedItems: [CleanupItem] {
        guard let report else { return [] }
        return report.items.filter { selectedItemIDs.contains($0.id) }
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.verifiedReclaimableBytes }
    }

    func cleanupItems(for scope: CleanupSelectionScope) -> [CleanupItem] {
        scope.resolve(
            from: report?.items ?? [],
            selectedItemIDs: selectedItemIDs
        )
    }

    func scan() async {
        guard !isScanning else { return }
        scanState = .scanning
        let settings = settingsStore.settings

        async let fileSystemTask = fileSystemScanner.scan(settings: settings)
        async let simulatorTask = simulatorScanner.scan(pinnedRuntimeIDs: settings.pinnedRuntimeIDs)
        async let xctestTask = xctestScanner.scan()
        async let processTask = processMonitor.activeRelatedProcesses()
        async let storageTask = diskStorageScanner.snapshot()

        let (fileSystemResult, simulatorResult, xctestResult, activeProcesses, currentStorage) = await (
            fileSystemTask,
            simulatorTask,
            xctestTask,
            processTask,
            storageTask
        )
        storageSnapshot = currentStorage

        let allItems = (fileSystemResult.items + simulatorResult.items + xctestResult.items).sorted {
            if $0.category == $1.category { return $0.byteCount > $1.byteCount }
            return $0.category.rawValue < $1.category.rawValue
        }
        let warnings = fileSystemResult.warnings + simulatorResult.warnings + xctestResult.warnings
        report = ScanReport(scannedAt: .now, items: allItems, activeProcesses: activeProcesses, warnings: warnings)
        itemsByCategory = Dictionary(grouping: allItems, by: \.category)
        selectedItemIDs = Set(allItems.filter(\.isRecommended).map(\.id))
        scanState = .idle
    }

    func setSelected(_ selected: Bool, item: CleanupItem) {
        if selected {
            selectedItemIDs.insert(item.id)
        } else {
            selectedItemIDs.remove(item.id)
        }
    }

    func setSelected(_ selected: Bool, category: CleanupCategory) {
        let ids = Set((itemsByCategory[category] ?? []).map(\.id))
        if selected {
            selectedItemIDs.formUnion(ids)
        } else {
            selectedItemIDs.subtract(ids)
        }
    }

    func cleanupPreview(for items: [CleanupItem]) -> DryRunPreview {
        return DryRunPreview(
            items: items,
            validations: Dictionary(uniqueKeysWithValues: items.map { ($0.id, validator.validate($0)) })
        )
    }

    func cleanupPreflight(for preview: DryRunPreview) async -> CleanupPreflight {
        await cleanupCoordinator.preflight(
            items: preview.items,
            pinnedRuntimeIDs: settingsStore.settings.pinnedRuntimeIDs
        )
    }

    func executeCleanup(
        preview: DryRunPreview,
        highRiskConfirmed: Bool,
        blockWhenRelatedProcessesAreActive: Bool = false,
        trigger: CleanupTrigger = .manual
    ) async -> CleanupReport? {
        guard !isCleaning else { return nil }
        isCleaning = true

        let report = await cleanupCoordinator.execute(
            items: preview.items,
            pinnedRuntimeIDs: settingsStore.settings.pinnedRuntimeIDs,
            highRiskConfirmed: highRiskConfirmed,
            blockWhenRelatedProcessesAreActive: blockWhenRelatedProcessesAreActive,
            trigger: trigger
        )
        lastCleanupReport = report
        selectedItemIDs.subtract(report.successfulResults.map(\.itemID))
        isCleaning = false

        Task { await scan() }
        return report
    }

    func runDueAutomations(at date: Date = .now) async {
        guard !isRunningAutomation, !isCleaning, !isScanning else { return }
        let dueCategories = settingsStore.settings.dueAutomationCategories(at: date)
        guard !dueCategories.isEmpty else { return }

        isRunningAutomation = true
        defer { isRunningAutomation = false }

        switch await processMonitor.inspectRelatedProcesses() {
        case .available(let activeProcesses) where !activeProcesses.isEmpty:
            automationStatus = .deferred(activeProcesses: activeProcesses)
            return
        case .available:
            break
        case .unavailable:
            automationStatus = .failed("Automatic cleanup could not verify whether development tools are active. It will retry later.")
            return
        }

        await scan()
        guard let report else {
            automationStatus = .failed("Automatic cleanup could not complete a scan. It will retry later.")
            return
        }

        let dueCleanupCategories = Set(dueCategories.map(\.cleanupCategory))
        let items = report.items.filter { dueCleanupCategories.contains($0.category) }
        let preview = cleanupPreview(for: items)
        switch await processMonitor.inspectRelatedProcesses() {
        case .available(let activeProcesses) where !activeProcesses.isEmpty:
            automationStatus = .deferred(activeProcesses: activeProcesses)
            return
        case .available:
            break
        case .unavailable:
            automationStatus = .failed("Automatic cleanup could not verify whether development tools are active. It will retry later.")
            return
        }

        guard let cleanupReport = await executeCleanup(
            preview: preview,
            highRiskConfirmed: false,
            blockWhenRelatedProcessesAreActive: true,
            trigger: .automation
        ) else {
            automationStatus = .failed("Automatic cleanup could not start. It will retry later.")
            return
        }

        let successfulIDs = Set(cleanupReport.successfulResults.map(\.itemID))
        let completedCategories = dueCategories.filter { automationCategory in
            let categoryIDs = Set(items.lazy
                .filter { $0.category == automationCategory.cleanupCategory }
                .map(\.id))
            return categoryIDs.isSubset(of: successfulIDs)
        }

        settingsStore.markAutomationRun(categories: completedCategories, at: date)
        if completedCategories.count == dueCategories.count {
            automationStatus = .completed(date)
        } else {
            automationStatus = .failed("Some automatic cleanup items could not be deleted. The app will retry later.")
        }
    }
}
