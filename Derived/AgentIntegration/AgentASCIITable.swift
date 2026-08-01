import Foundation

nonisolated public struct AgentTableColumn: Sendable {
    public enum Alignment: Sendable {
        case leading
        case trailing
    }

    public let title: String
    public let alignment: Alignment
    public let maximumWidth: Int?

    public init(
        _ title: String,
        alignment: Alignment = .leading,
        maximumWidth: Int? = nil
    ) {
        self.title = title
        self.alignment = alignment
        self.maximumWidth = maximumWidth
    }
}

nonisolated public enum AgentASCIITable {
    public static func render(columns: [AgentTableColumn], rows: [[String]]) -> String {
        guard !columns.isEmpty else { return "" }

        let normalizedRows = rows.map { row in
            columns.indices.map { index in
                index < row.count ? clipped(row[index], maximumWidth: columns[index].maximumWidth) : ""
            }
        }
        let headings = columns.map { clipped($0.title, maximumWidth: $0.maximumWidth) }
        let widths = columns.indices.map { index in
            max(headings[index].count, normalizedRows.map { $0[index].count }.max() ?? 0)
        }
        let border = "+" + widths.map { String(repeating: "-", count: $0 + 2) }.joined(separator: "+") + "+"
        let header = row(headings, columns: columns, widths: widths)
        let body = normalizedRows.map { row($0, columns: columns, widths: widths) }
        return ([border, header, border] + body + [border]).joined(separator: "\n")
    }

    private static func row(
        _ values: [String],
        columns: [AgentTableColumn],
        widths: [Int]
    ) -> String {
        let cells = values.indices.map { index in
            let padding = String(repeating: " ", count: widths[index] - values[index].count)
            return switch columns[index].alignment {
            case .leading: values[index] + padding
            case .trailing: padding + values[index]
            }
        }
        return "| " + cells.joined(separator: " | ") + " |"
    }

    private static func clipped(_ value: String, maximumWidth: Int?) -> String {
        guard let maximumWidth, maximumWidth >= 4, value.count > maximumWidth else { return value }
        return String(value.prefix(maximumWidth - 3)) + "..."
    }
}
