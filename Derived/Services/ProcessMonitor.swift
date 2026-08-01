import Foundation

actor ProcessMonitor {
    private let runner: any CommandRunning
    private let processNames = [
        "Xcode",
        "Xcode Helper",
        "XcodeBuildService",
        "XCBBuildService",
        "xcodebuild",
        "Simulator",
        "xctest",
        "CoreSimulatorService",
        "simctl",
        "swift-build",
        "swiftc"
    ]

    init(runner: any CommandRunning = FoundationCommandRunner()) {
        self.runner = runner
    }

    func activeRelatedProcesses() async -> [String] {
        switch await inspectRelatedProcesses() {
        case .available(let activeProcesses): activeProcesses
        case .unavailable: []
        }
    }

    func inspectRelatedProcesses() async -> ProcessInspection {
        do {
            let result = try await runner.run(executable: "/usr/bin/ps", arguments: ["-axo", "comm="])
            guard result.succeeded else { return .unavailable }
            let processes = result.standardOutput
                .split(separator: "\n")
                .map(String.init)
                .map { URL(filePath: $0).lastPathComponent }
                .filter { candidate in
                    processNames.contains { watched in
                        candidate.localizedCaseInsensitiveCompare(watched) == .orderedSame
                            || candidate.hasPrefix(watched + " ")
                    }
                }
            return .available(activeProcesses: Array(Set(processes)).sorted())
        } catch {
            return .unavailable
        }
    }
}
