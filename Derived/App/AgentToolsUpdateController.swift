import AppKit
import Observation

@Observable
@MainActor
final class AgentToolsUpdateController {
    private(set) var state: AgentToolsUpdateState = .idle
    private(set) var didCopyHomebrewCommand = false
    private(set) var isDeferred = false

    private let service: AgentToolsUpdateService

    init(service: AgentToolsUpdateService = AgentToolsUpdateService()) {
        self.service = service
    }

    var availableUpdate: AgentToolsUpdateAvailability? {
        switch state {
        case .available(let availability), .updating(let availability), .failed(let availability, _):
            availability
        case .idle, .checking, .completed:
            nil
        }
    }

    var shouldShowCard: Bool {
        availableUpdate != nil && !isDeferred
    }

    func checkIfNeeded() async {
        guard state == .idle else { return }
        state = .checking
        if let availability = await service.availability() {
            state = .available(availability)
        } else {
            state = .idle
        }
    }

    func installUpdate() async {
        guard let availability = availableUpdate,
              availability.installationKind == .dmg else {
            return
        }

        state = .updating(availability)
        do {
            state = .completed(try await service.install(availability))
        } catch {
            state = .failed(availability, error.localizedDescription)
        }
    }

    func copyHomebrewCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("derived integrations update", forType: .string)
        didCopyHomebrewCommand = true
    }

    func deferUpdate() {
        isDeferred = true
    }
}
