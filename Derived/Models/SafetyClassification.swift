import Foundation

nonisolated enum SafetyClassification: Int, CaseIterable, Codable, Identifiable, Comparable, Sendable {
    case recommended
    case caution
    case highRisk

    var id: Self { self }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
