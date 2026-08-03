import Foundation

struct CLIExecutableLocator {
    let fileManager: FileManager
    let environment: [String: String]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.environment = environment
    }

    func resolve(_ invocation: URL) -> URL {
        let resolvedInvocation = invocation.resolvingSymlinksInPath().standardizedFileURL
        if fileManager.isExecutableFile(atPath: resolvedInvocation.path) {
            return resolvedInvocation
        }

        if let executable = executable(named: invocation.lastPathComponent) {
            return executable.resolvingSymlinksInPath().standardizedFileURL
        }

        return resolvedInvocation
    }

    func executable(named name: String) -> URL? {
        let paths = (environment["PATH"] ?? "").split(separator: ":")
        return paths
            .map { URL(fileURLWithPath: String($0)).appending(path: name) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}
