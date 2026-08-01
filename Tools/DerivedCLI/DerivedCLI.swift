import Darwin
import DerivedCore
import Foundation

@main
struct DerivedCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        do {
            let command = try CLIArguments.parse(arguments)
            let service = DerivedAgentService()
            switch command {
            case .help:
                print(help)
            case .version:
                print(DerivedAgentVersion.cliDescription)
            case .scan(let json):
                let result = try await CLIProgress.run("Scanning developer storage") {
                    try await service.scan()
                }
                print(try json ? CLIOutput.json(result) : CLIOutput.scan(result))
            case .list(let scanID, let category, let offset, let limit, let json):
                let result = try await service.listCandidates(
                    scanID: scanID,
                    category: category,
                    offset: offset,
                    limit: limit
                )
                print(try json ? CLIOutput.json(result) : CLIOutput.page(result))
            case .prepare(let scanID, let selection, let json):
                let result = try await CLIProgress.run("Preparing cleanup plan") {
                    try await service.prepareCleanup(scanID: scanID, selection: selection)
                }
                print(try json ? CLIOutput.json(result) : CLIOutput.plan(result))
            case .delete(let planID, let confirmation, let json):
                let result = try await CLIProgress.run("Permanently deleting selected data") {
                    try await service.executeCleanup(planID: planID, confirmationPhrase: confirmation)
                }
                print(try json ? CLIOutput.json(result) : CLIOutput.result(result))
            }
        } catch {
            FileHandle.standardError.write(Data("derived: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static let help = """
    Derived command-line interface

    Usage:
      derived --version
      derived scan [--json]
      derived list --scan <UUID> --category <category> [--offset N] [--limit N] [--json]
      derived prepare --scan <UUID> [--item <candidate-id>]... [--category <category>]... [--json]
      derived delete --plan <UUID> --confirm <exact-phrase> [--json]

    Cleanup is permanent. A fresh scan and cleanup plan are required before deletion.
    """
}
