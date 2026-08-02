import AppKit

@main
@MainActor
struct DerivedAgentToolsInstallerMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = InstallerAppDelegate()

        application.setActivationPolicy(.regular)
        application.delegate = delegate
        application.finishLaunching()

        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
