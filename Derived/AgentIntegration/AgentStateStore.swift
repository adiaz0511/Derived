import Foundation

nonisolated struct StoredAgentScan: Codable, Sendable {
    let id: UUID
    let scannedAt: Date
    let expiresAt: Date
    let items: [CleanupItem]
    let activeProcesses: [String]
    let warnings: [String]
    let pinnedRuntimeIDs: Set<String>
}

nonisolated struct StoredAgentPlan: Codable, Sendable {
    let id: UUID
    let scanID: UUID
    let createdAt: Date
    let expiresAt: Date
    let items: [CleanupItem]
    let pinnedRuntimeIDs: Set<String>
    let confirmationPhrase: String
    let requiresAdditionalConfirmation: Bool
}

actor AgentStateStore {
    private let root: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(root: URL? = nil, fileManager: FileManager = .default) {
        self.root = root ?? URL.applicationSupportDirectory
            .appending(path: "Derived", directoryHint: .isDirectory)
            .appending(path: "Agent", directoryHint: .isDirectory)
        self.fileManager = fileManager
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(scan: StoredAgentScan) throws {
        try save(scan, at: scanURL(scan.id))
    }

    func loadScan(id: UUID) throws -> StoredAgentScan? {
        try load(StoredAgentScan.self, at: scanURL(id))
    }

    func save(plan: StoredAgentPlan) throws {
        try save(plan, at: planURL(plan.id))
    }

    func loadPlan(id: UUID) throws -> StoredAgentPlan? {
        try load(StoredAgentPlan.self, at: planURL(id))
    }

    func removePlan(id: UUID) throws {
        let url = planURL(id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func removeExpired(before date: Date) throws {
        for directory in [scanDirectory, planDirectory] {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in urls where expiryDate(at: url).map({ $0 <= date }) == true {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private var scanDirectory: URL {
        root.appending(path: "Scans", directoryHint: .isDirectory)
    }

    private var planDirectory: URL {
        root.appending(path: "Plans", directoryHint: .isDirectory)
    }

    private func scanURL(_ id: UUID) -> URL {
        scanDirectory.appending(path: "\(id.uuidString).json")
    }

    private func planURL(_ id: UUID) -> URL {
        planDirectory.appending(path: "\(id.uuidString).json")
    }

    private func save<T: Encodable>(_ value: T, at url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: [.atomic, .completeFileProtection])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func load<T: Decodable>(_ type: T.Type, at url: URL) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    private func expiryDate(at url: URL) -> Date? {
        if url.deletingLastPathComponent().lastPathComponent == "Scans" {
            return try? load(StoredAgentScan.self, at: url)?.expiresAt
        }
        return try? load(StoredAgentPlan.self, at: url)?.expiresAt
    }
}
