import Foundation

@MainActor
final class CleanupAutomationMonitor {
    private let model: AppModel
    private var monitoringTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await model.runDueAutomations()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    func checkNow() async {
        await model.runDueAutomations()
    }

    func stop() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
}
