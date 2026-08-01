import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginController {
    private(set) var isEnabled = false
    private(set) var requiresApproval = false
    private(set) var isChanging = false
    private(set) var errorMessage = ""
    var isShowingError = false

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        guard !isChanging, enabled != isEnabled else { return }

        if enabled, requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }

        isChanging = true
        Task {
            defer {
                refresh()
                isChanging = false
            }

            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    if SMAppService.mainApp.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                } else {
                    try await SMAppService.mainApp.unregister()
                }
            } catch {
                errorMessage = error.localizedDescription
                isShowingError = true
            }
        }
    }
}
