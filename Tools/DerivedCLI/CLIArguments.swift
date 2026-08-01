import DerivedCore
import Foundation

enum CLICommand {
    case help
    case version
    case scan(json: Bool)
    case list(scanID: UUID, category: AgentCategory, offset: Int, limit: Int, json: Bool)
    case prepare(scanID: UUID, selection: AgentCleanupSelection, json: Bool)
    case delete(planID: UUID, confirmation: String, json: Bool)
}

enum CLIArgumentError: LocalizedError {
    case invalidValue(String)
    case missingOption(String)
    case unknownCommand(String)

    var errorDescription: String? {
        switch self {
        case .invalidValue(let value): "Invalid argument value: \(value)."
        case .missingOption(let option): "Missing required option: \(option)."
        case .unknownCommand(let command): "Unknown command: \(command)."
        }
    }
}

struct CLIArguments {
    static func parse(_ arguments: [String]) throws -> CLICommand {
        guard let command = arguments.first else { return .help }
        let remaining = Array(arguments.dropFirst())
        switch command {
        case "help", "--help", "-h":
            return .help
        case "version", "--version", "-V":
            return .version
        case "scan":
            return .scan(json: remaining.contains("--json"))
        case "list":
            return try parseList(remaining)
        case "prepare":
            return try parsePrepare(remaining)
        case "delete":
            return try parseDelete(remaining)
        default:
            throw CLIArgumentError.unknownCommand(command)
        }
    }

    private static func parseList(_ arguments: [String]) throws -> CLICommand {
        let options = ParsedOptions(arguments)
        guard let scanValue = options.first("--scan"), let scanID = UUID(uuidString: scanValue) else {
            throw CLIArgumentError.missingOption("--scan <UUID>")
        }
        guard let categoryValue = options.first("--category"),
              let category = AgentCategory(rawValue: categoryValue) else {
            throw CLIArgumentError.missingOption("--category <category>")
        }
        let offset = try options.integer("--offset", default: 0)
        let limit = try options.integer("--limit", default: 20)
        return .list(scanID: scanID, category: category, offset: offset, limit: limit, json: options.has("--json"))
    }

    private static func parsePrepare(_ arguments: [String]) throws -> CLICommand {
        let options = ParsedOptions(arguments)
        guard let scanValue = options.first("--scan"), let scanID = UUID(uuidString: scanValue) else {
            throw CLIArgumentError.missingOption("--scan <UUID>")
        }
        let categories = try options.values("--category").map { value in
            guard let category = AgentCategory(rawValue: value) else {
                throw CLIArgumentError.invalidValue(value)
            }
            return category
        }
        let selection = AgentCleanupSelection(itemIDs: options.values("--item"), categories: categories)
        return .prepare(scanID: scanID, selection: selection, json: options.has("--json"))
    }

    private static func parseDelete(_ arguments: [String]) throws -> CLICommand {
        let options = ParsedOptions(arguments)
        guard let planValue = options.first("--plan"), let planID = UUID(uuidString: planValue) else {
            throw CLIArgumentError.missingOption("--plan <UUID>")
        }
        guard let confirmation = options.first("--confirm") else {
            throw CLIArgumentError.missingOption("--confirm <phrase>")
        }
        return .delete(planID: planID, confirmation: confirmation, json: options.has("--json"))
    }
}

private struct ParsedOptions {
    private let arguments: [String]

    init(_ arguments: [String]) {
        self.arguments = arguments
    }

    func has(_ name: String) -> Bool {
        arguments.contains(name)
    }

    func first(_ name: String) -> String? {
        values(name).first
    }

    func values(_ name: String) -> [String] {
        arguments.indices.compactMap { index in
            guard arguments[index] == name, arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
    }

    func integer(_ name: String, default defaultValue: Int) throws -> Int {
        guard let value = first(name) else { return defaultValue }
        guard let integer = Int(value) else { throw CLIArgumentError.invalidValue(value) }
        return integer
    }
}
