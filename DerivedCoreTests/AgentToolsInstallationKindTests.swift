@testable import DerivedCore
import Foundation
import Testing

struct AgentToolsInstallationKindTests {
    @Test
    func classifiesDMGInstallation() {
        let home = URL(fileURLWithPath: "/Users/example")
        let executable = home.appending(path: ".local/bin/derived")

        #expect(AgentToolsInstallationKind.classify(executableURL: executable, homeDirectory: home) == .dmg)
    }

    @Test
    func classifiesHomebrewInstallation() {
        let home = URL(fileURLWithPath: "/Users/example")
        let executable = URL(
            fileURLWithPath: "/opt/homebrew/Caskroom/derived-tools/1.0.4/.agent-tools/bin/derived"
        )

        #expect(AgentToolsInstallationKind.classify(executableURL: executable, homeDirectory: home) == .homebrew)
    }

    @Test
    func classifiesDevelopmentInstallationAsManual() {
        let home = URL(fileURLWithPath: "/Users/example")
        let executable = home.appending(path: "Developer/Derived/.build/release/derived")

        #expect(AgentToolsInstallationKind.classify(executableURL: executable, homeDirectory: home) == .manual)
    }
}
