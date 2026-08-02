@testable import DerivedCLI
import Testing

struct CLIArgumentsTests {
    @Test(arguments: ["version", "--version", "-V"])
    func parsesVersionAliases(_ argument: String) throws {
        let command = try CLIArguments.parse([argument])

        guard case .version = command else {
            Issue.record("Expected the version command")
            return
        }
    }

    @Test
    func parsesIntegrationInstallForSpecificClient() throws {
        let command = try CLIArguments.parse(["integrations", "install", "--client", "cursor"])

        guard case .integrations(.install(client: .cursor)) = command else {
            Issue.record("Expected a Cursor integration installation")
            return
        }
    }

    @Test
    func parsesIntegrationStatus() throws {
        let command = try CLIArguments.parse(["integrations", "status"])

        guard case .integrations(.status) = command else {
            Issue.record("Expected the integration status command")
            return
        }
    }
}
