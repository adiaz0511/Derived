import AppKit

@MainActor
final class InstallerAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var installButton: NSButton?
    private var uninstallButton: NSButton?
    private var closeButton: NSButton?
    private var progressIndicator: NSProgressIndicator?
    private var statusIconView: NSImageView?
    private var statusLabel: NSTextField?
    private var outputTextView: NSTextView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = makeWindow()
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func installAgentTools() {
        runAgentToolsScript(
            named: "install-codex-agent-tools.sh",
            progressMessage: "Installing the CLI, MCP server, and Codex skill…",
            successMessage: "Installation complete. Restart Codex before using Derived."
        )
    }

    @objc private func uninstallAgentTools() {
        let alert = NSAlert()
        alert.messageText = "Remove Derived Agent Tools?"
        alert.informativeText = "This removes the Derived CLI, MCP registration, and Codex skill. Application preferences and cleanup history are retained."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        runAgentToolsScript(
            named: "uninstall-codex-agent-tools.sh",
            progressMessage: "Removing the CLI, MCP server, and Codex skill…",
            successMessage: "Derived Agent Tools were removed."
        )
    }

    @objc private func closeInstaller() {
        window?.performClose(nil)
    }

    private func runAgentToolsScript(
        named scriptName: String,
        progressMessage: String,
        successMessage: String
    ) {
        guard let resourceURL = Bundle.main.resourceURL else {
            finishOperation(message: "The installer resources could not be found.", output: "", succeeded: false)
            return
        }

        let agentToolsURL = resourceURL.appendingPathComponent("Agent Tools", isDirectory: true)
        let scriptURL = agentToolsURL.appendingPathComponent(scriptName)
        guard FileManager.default.isExecutableFile(atPath: scriptURL.path) else {
            finishOperation(message: "The bundled installer script is missing.", output: scriptURL.path, succeeded: false)
            return
        }

        setOperationRunning(true, message: progressMessage)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]

        var environment = ProcessInfo.processInfo.environment
        environment["DERIVED_AGENT_TOOLS_SOURCE_DIR"] = agentToolsURL.path
        process.environment = environment

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
        } catch {
            finishOperation(message: "The operation could not start.", output: error.localizedDescription, succeeded: false)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let succeeded = process.terminationStatus == 0

            DispatchQueue.main.async {
                self?.finishOperation(
                    message: succeeded ? successMessage : "The operation did not complete.",
                    output: output,
                    succeeded: succeeded
                )
            }
        }
    }

    private func setOperationRunning(_ running: Bool, message: String) {
        installButton?.isHidden = false
        uninstallButton?.isHidden = false
        installButton?.isEnabled = !running
        uninstallButton?.isEnabled = !running && agentToolsAreInstalled
        installButton?.keyEquivalent = running ? "" : "\r"
        closeButton?.isHidden = true
        closeButton?.keyEquivalent = ""
        statusLabel?.stringValue = message
        statusLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel?.textColor = .labelColor
        statusIconView?.isHidden = true
        outputTextView?.string = ""

        if running {
            progressIndicator?.startAnimation(nil)
        } else {
            progressIndicator?.stopAnimation(nil)
        }
    }

    private func finishOperation(message: String, output: String, succeeded: Bool) {
        setOperationRunning(false, message: message)
        outputTextView?.string = output.trimmingCharacters(in: .whitespacesAndNewlines)

        let symbolName = succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        let statusColor: NSColor = succeeded ? .systemGreen : .systemRed
        statusIconView?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: succeeded ? "Operation completed successfully" : "Operation failed"
        )
        statusIconView?.contentTintColor = statusColor
        statusIconView?.isHidden = false
        statusLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        statusLabel?.textColor = statusColor
        installButton?.isHidden = succeeded
        uninstallButton?.isHidden = succeeded
        closeButton?.isHidden = false
        closeButton?.keyEquivalent = "\r"
        installButton?.keyEquivalent = ""

        if !succeeded {
            NSSound.beep()
        }
    }

    private var agentToolsAreInstalled: Bool {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return FileManager.default.fileExists(
            atPath: homeDirectory.appendingPathComponent(".local/bin/derived").path
        )
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Derived Agent Tools"
        window.isReleasedWhenClosed = false

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let iconView = NSImageView()
        iconView.image = NSApplication.shared.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Derived Agent Tools")
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = NSTextField(wrappingLabelWithString: "Install the Derived CLI, local MCP server, and cleanup skill for Codex. Everything is installed within your user account and does not require administrator access.")
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .center
        descriptionLabel.maximumNumberOfLines = 3
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusLabel = NSTextField(labelWithString: "Ready to install.")
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        self.statusLabel = statusLabel

        let statusIconView = NSImageView()
        statusIconView.imageScaling = .scaleProportionallyUpOrDown
        statusIconView.isHidden = true
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        self.statusIconView = statusIconView

        let progressIndicator = NSProgressIndicator()
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.progressIndicator = progressIndicator

        let outputTextView = NSTextView()
        outputTextView.isEditable = false
        outputTextView.isSelectable = true
        outputTextView.drawsBackground = false
        outputTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        outputTextView.textColor = .secondaryLabelColor
        outputTextView.textContainerInset = NSSize(width: 8, height: 8)
        outputTextView.string = """
        CLI      ~/.local/bin/derived
        MCP      ~/.local/bin/derived-mcp
        Skill    ~/.codex/skills/derived-cleanup
        """
        self.outputTextView = outputTextView

        let outputScrollView = NSScrollView()
        outputScrollView.documentView = outputTextView
        outputScrollView.hasVerticalScroller = true
        outputScrollView.borderType = .bezelBorder
        outputScrollView.translatesAutoresizingMaskIntoConstraints = false

        let installButton = NSButton(title: "Install for Codex", target: self, action: #selector(installAgentTools))
        installButton.bezelStyle = .rounded
        installButton.controlSize = .large
        installButton.keyEquivalent = "\r"
        installButton.translatesAutoresizingMaskIntoConstraints = false
        self.installButton = installButton

        let uninstallButton = NSButton(title: "Remove", target: self, action: #selector(uninstallAgentTools))
        uninstallButton.bezelStyle = .rounded
        uninstallButton.controlSize = .large
        uninstallButton.translatesAutoresizingMaskIntoConstraints = false
        self.uninstallButton = uninstallButton
        uninstallButton.isEnabled = agentToolsAreInstalled

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeInstaller))
        closeButton.bezelStyle = .rounded
        closeButton.controlSize = .large
        closeButton.isHidden = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        self.closeButton = closeButton

        let buttonStack = NSStackView(views: [uninstallButton, installButton, closeButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.distribution = .fill
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let statusStack = NSStackView(views: [progressIndicator, statusIconView, statusLabel])
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = 8
        statusStack.translatesAutoresizingMaskIntoConstraints = false

        [iconView, titleLabel, descriptionLabel, statusStack, outputScrollView, buttonStack].forEach(contentView.addSubview)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 72),
            iconView.heightAnchor.constraint(equalToConstant: 72),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 54),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -54),

            statusStack.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 18),
            statusStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            outputScrollView.topAnchor.constraint(equalTo: statusStack.bottomAnchor, constant: 14),
            outputScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            outputScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            outputScrollView.heightAnchor.constraint(equalToConstant: 100),

            buttonStack.topAnchor.constraint(equalTo: outputScrollView.bottomAnchor, constant: 18),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            installButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            uninstallButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),
            statusIconView.widthAnchor.constraint(equalToConstant: 22),
            statusIconView.heightAnchor.constraint(equalToConstant: 22)
        ])

        return window
    }
}
