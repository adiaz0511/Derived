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
}
