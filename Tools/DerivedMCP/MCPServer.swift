import DerivedCore
import Foundation

actor MCPServer {
    private let service: DerivedAgentService
    private let encoder: JSONEncoder

    init(service: DerivedAgentService = DerivedAgentService()) {
        self.service = service
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    }

    func handle(_ request: [String: Any]) async -> [String: Any]? {
        let method = request["method"] as? String
        let identifier = request["id"]
        switch method {
        case "initialize":
            guard let identifier else { return nil }
            let parameters = request["params"] as? [String: Any]
            let requestedVersion = parameters?["protocolVersion"] as? String
            return response(id: identifier, result: [
                "protocolVersion": negotiatedVersion(requestedVersion),
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": ["name": "derived", "version": DerivedAgentVersion.current],
                "instructions": Self.instructions
            ])
        case "notifications/initialized", "notifications/cancelled":
            return nil
        case "ping":
            guard let identifier else { return nil }
            return response(id: identifier, result: [:])
        case "tools/list":
            guard let identifier else { return nil }
            return response(id: identifier, result: ["tools": MCPToolDefinitions.all])
        case "tools/call":
            guard let identifier else { return nil }
            return await callTool(request: request, id: identifier)
        default:
            guard let identifier else { return nil }
            return errorResponse(id: identifier, code: -32601, message: "Method not found")
        }
    }

    private func callTool(request: [String: Any], id: Any) async -> [String: Any] {
        guard let parameters = request["params"] as? [String: Any],
              let name = parameters["name"] as? String else {
            return errorResponse(id: id, code: -32602, message: "Invalid tool parameters")
        }
        let arguments = parameters["arguments"] as? [String: Any] ?? [:]
        do {
            let value: Any
            switch name {
            case "scan":
                value = try jsonObject(try await service.scan())
            case "list_candidates":
                let scanID = try uuid(arguments, key: "scan_id")
                let category = try category(arguments, key: "category")
                let offset = arguments["offset"] as? Int ?? 0
                let limit = arguments["limit"] as? Int ?? 20
                value = try jsonObject(try await service.listCandidates(
                    scanID: scanID,
                    category: category,
                    offset: offset,
                    limit: limit
                ))
            case "prepare_cleanup":
                let scanID = try uuid(arguments, key: "scan_id")
                let itemIDs = arguments["item_ids"] as? [String] ?? []
                let categories = try (arguments["categories"] as? [String] ?? []).map { value in
                    guard let category = AgentCategory(rawValue: value) else {
                        throw AgentIntegrationError.invalidCategory(value)
                    }
                    return category
                }
                value = try jsonObject(try await service.prepareCleanup(
                    scanID: scanID,
                    selection: AgentCleanupSelection(itemIDs: itemIDs, categories: categories)
                ))
            case "execute_cleanup":
                let planID = try uuid(arguments, key: "plan_id")
                guard let confirmation = arguments["confirmation_phrase"] as? String else {
                    throw MCPInputError.missing("confirmation_phrase")
                }
                value = try jsonObject(try await service.executeCleanup(
                    planID: planID,
                    confirmationPhrase: confirmation
                ))
            default:
                return errorResponse(id: id, code: -32602, message: "Unknown tool: \(name)")
            }
            let text = try jsonText(value)
            return response(id: id, result: [
                "content": [["type": "text", "text": text]],
                "structuredContent": value,
                "isError": false
            ])
        } catch {
            return response(id: id, result: [
                "content": [["type": "text", "text": error.localizedDescription]],
                "isError": true
            ])
        }
    }

    private func uuid(_ arguments: [String: Any], key: String) throws -> UUID {
        guard let value = arguments[key] as? String, let identifier = UUID(uuidString: value) else {
            throw MCPInputError.invalid(key)
        }
        return identifier
    }

    private func category(_ arguments: [String: Any], key: String) throws -> AgentCategory {
        guard let value = arguments[key] as? String else { throw MCPInputError.missing(key) }
        guard let category = AgentCategory(rawValue: value) else {
            throw AgentIntegrationError.invalidCategory(value)
        }
        return category
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: encoder.encode(value))
    }

    private func jsonText(_ object: Any) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), as: UTF8.self)
    }

    private func response(id: Any, result: Any) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private func errorResponse(id: Any, code: Int, message: String) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]]
    }

    private func negotiatedVersion(_ requestedVersion: String?) -> String {
        let supportedVersions = ["2024-11-05", "2025-03-26", "2025-06-18"]
        guard let requestedVersion, supportedVersions.contains(requestedVersion) else {
            return "2025-06-18"
        }
        return requestedVersion
    }

    private static let instructions = """
    Derived scans and permanently deletes local Xcode-generated data. Always scan first. Use list_candidates with pagination rather than requesting every XCTest item at once. Use prepare_cleanup before deletion, present its count, categories, size, warnings, and exact confirmation phrase to the user, and call execute_cleanup only after explicit approval. Never invent candidate IDs or filesystem paths. Never bypass a high-risk warning.
    """
}

private enum MCPInputError: LocalizedError {
    case invalid(String)
    case missing(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let key): "Invalid value for \(key)."
        case .missing(let key): "Missing required value: \(key)."
        }
    }
}
