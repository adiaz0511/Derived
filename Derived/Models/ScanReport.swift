import Foundation

struct ScanReport: Sendable {
    let scannedAt: Date
    let items: [CleanupItem]
    let activeProcesses: [String]
    let warnings: [String]

    var discoveredBytes: Int64 {
        items.reduce(0) { $0 + $1.verifiedReclaimableBytes }
    }

    var recommendedBytes: Int64 {
        items.filter(\.isRecommended).reduce(0) { $0 + $1.verifiedReclaimableBytes }
    }

    func items(in category: CleanupCategory) -> [CleanupItem] {
        items.filter { $0.category == category }
    }
}
