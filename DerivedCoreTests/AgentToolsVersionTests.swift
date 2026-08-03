@testable import DerivedCore
import Foundation
import Testing

struct AgentToolsVersionTests {
    @Test
    func comparesReleaseVersionsNumerically() throws {
        let older = try #require(AgentToolsVersion("1.0.9"))
        let newer = try #require(AgentToolsVersion("1.0.10"))

        #expect(older < newer)
    }

    @Test
    func releaseIsNewerThanItsPrerelease() throws {
        let prerelease = try #require(AgentToolsVersion("1.0.4-beta.1"))
        let release = try #require(AgentToolsVersion("1.0.4"))

        #expect(prerelease < release)
    }

    @Test
    func rejectsIncompleteVersions() {
        #expect(AgentToolsVersion("1.0") == nil)
        #expect(AgentToolsVersion("release") == nil)
    }
}
