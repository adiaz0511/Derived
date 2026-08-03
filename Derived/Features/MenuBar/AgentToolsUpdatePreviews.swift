import SwiftUI

#Preview("DMG Update Available") {
    AgentToolsUpdateAvailableView(
        availability: previewAvailability(for: .dmg),
        didCopyHomebrewCommand: false,
        update: {},
        copyCommand: {},
        close: {}
    )
    .frame(width: 460, height: 240)
}

#Preview("Homebrew Update Available") {
    AgentToolsUpdateAvailableView(
        availability: previewAvailability(for: .homebrew),
        didCopyHomebrewCommand: false,
        update: {},
        copyCommand: {},
        close: {}
    )
    .frame(width: 460, height: 300)
}

#Preview("Updating") {
    AgentToolsUpdateProgressView()
        .frame(width: 460, height: 240)
}

#Preview("Update Completed") {
    AgentToolsUpdateCompletionView(
        result: AgentToolsUpdateResult(
            version: "1.0.5",
            detail: "Version 1.0.5 is installed for Codex and Cursor. Restart these apps before using Derived."
        ),
        close: {}
    )
    .frame(width: 460, height: 240)
}

#Preview("Update Failed") {
    AgentToolsUpdateFailureView(
        availability: previewAvailability(for: .dmg),
        message: "The Agent Tools payload could not be verified.",
        retry: {},
        close: {}
    )
    .frame(width: 460, height: 320)
}

private func previewAvailability(
    for installationKind: AgentToolsInstallationKind
) -> AgentToolsUpdateAvailability {
    guard let installedVersion = AgentToolsVersion("1.0.4"),
          let availableVersion = AgentToolsVersion("1.0.5") else {
        preconditionFailure("Preview versions must use semantic versioning.")
    }

    return AgentToolsUpdateAvailability(
        installationKind: installationKind,
        installedVersion: installedVersion,
        availableVersion: availableVersion,
        payloadRoot: URL(fileURLWithPath: "/Applications/Derived.app/Contents/Resources/AgentTools"),
        installedClients: ["Codex", "Cursor"]
    )
}
