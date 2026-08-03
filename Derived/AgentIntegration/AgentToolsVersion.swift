import Foundation

nonisolated public struct AgentToolsVersion: Codable, Comparable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?

    public init?(_ value: String) {
        let components = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = components[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
              let major = Int(numbers[0]),
              let minor = Int(numbers[1]),
              let patch = Int(numbers[2]),
              major >= 0,
              minor >= 0,
              patch >= 0 else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        prerelease = components.count == 2 && !components[1].isEmpty ? String(components[1]) : nil
    }

    public var description: String {
        let release = "\(major).\(minor).\(patch)"
        guard let prerelease else { return release }
        return "\(release)-\(prerelease)"
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let lhsNumbers = [lhs.major, lhs.minor, lhs.patch]
        let rhsNumbers = [rhs.major, rhs.minor, rhs.patch]
        if lhsNumbers != rhsNumbers {
            return lhsNumbers.lexicographicallyPrecedes(rhsNumbers)
        }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case (.some(let lhsPrerelease), .some(let rhsPrerelease)):
            return lhsPrerelease.localizedStandardCompare(rhsPrerelease) == .orderedAscending
        }
    }
}
