import DerivedCore
import Foundation

enum CLIOutput {
    static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    static func scan(_ scan: AgentScan) -> String {
        let categoryRows = scan.categories.map { category in
            [
                category.category.title,
                category.category.rawValue,
                String(category.itemCount),
                String(category.recommendedItemCount),
                format(category.verifiedReclaimableBytes),
                category.logicalBytes > 0 ? format(category.logicalBytes) : "-"
            ]
        }
        let totalRow = [
            "Total",
            "-",
            String(scan.categories.reduce(0) { $0 + $1.itemCount }),
            String(scan.categories.reduce(0) { $0 + $1.recommendedItemCount }),
            format(scan.categories.reduce(Int64(0)) { $0 + $1.verifiedReclaimableBytes }),
            scan.categories.contains { $0.logicalBytes > 0 }
                ? format(scan.categories.reduce(Int64(0)) { $0 + $1.logicalBytes })
                : "-"
        ]
        let table = AgentASCIITable.render(
            columns: [
                AgentTableColumn("Category", maximumWidth: 26),
                AgentTableColumn("Key", maximumWidth: 23),
                AgentTableColumn("Items", alignment: .trailing),
                AgentTableColumn("Recommended", alignment: .trailing),
                AgentTableColumn("Reclaimable", alignment: .trailing),
                AgentTableColumn("Logical", alignment: .trailing)
            ],
            rows: categoryRows + [totalRow]
        )
        var lines = [
            "Derived scan complete",
            "Scan ID: \(scan.scanID.uuidString)",
            "",
            table
        ]
        if !scan.activeProcesses.isEmpty {
            lines.append("")
            lines.append("Active development tools: \(scan.activeProcesses.joined(separator: ", "))")
        }
        if !scan.warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            lines.append(contentsOf: scan.warnings.map { "- \($0)" })
        }
        lines.append("")
        lines.append("Use `derived list --scan \(scan.scanID.uuidString) --category <category>` to inspect candidates.")
        return lines.joined(separator: "\n")
    }

    static func page(_ page: AgentCandidatePage) -> String {
        let table = AgentASCIITable.render(
            columns: [
                AgentTableColumn("#", alignment: .trailing),
                AgentTableColumn("Name", maximumWidth: 36),
                AgentTableColumn("Size", alignment: .trailing),
                AgentTableColumn("Status", maximumWidth: 14),
                AgentTableColumn("Candidate ID", maximumWidth: 42)
            ],
            rows: page.candidates.enumerated().map { index, candidate in
                [
                    String(page.offset + index + 1),
                    candidate.name,
                    candidate.logicalSizeOnly
                        ? "\(format(candidate.byteCount)) logical"
                        : format(candidate.verifiedReclaimableBytes),
                    status(candidate),
                    candidate.id
                ]
            }
        )
        var lines = [
            "\(page.category.title) candidates (\(page.totalCount) total)",
            "",
            table
        ]
        if let nextOffset = page.nextOffset {
            lines.append("")
            lines.append("Next page: add `--offset \(nextOffset)`.")
        }
        lines.append("Use `--json` when you need complete, untruncated candidate IDs.")
        return lines.joined(separator: "\n")
    }

    static func plan(_ plan: AgentCleanupPlan) -> String {
        let table = AgentASCIITable.render(
            columns: [
                AgentTableColumn("Items", alignment: .trailing),
                AgentTableColumn("Reclaimable", alignment: .trailing),
                AgentTableColumn("Logical", alignment: .trailing),
                AgentTableColumn("Risk")
            ],
            rows: [[
                String(plan.itemCount),
                format(plan.verifiedReclaimableBytes),
                plan.logicalBytes > 0 ? format(plan.logicalBytes) : "-",
                plan.requiresAdditionalConfirmation ? "High-risk items" : "Standard"
            ]]
        )
        return """
        Cleanup plan: \(plan.planID.uuidString)
        Categories: \(plan.categories.map(\.title).joined(separator: ", "))

        \(table)

        Confirmation phrase: \(plan.confirmationPhrase)

        Review the plan above. To permanently delete these items within 10 minutes, run:
        derived delete --plan \(plan.planID.uuidString) --confirm \(shellQuote(plan.confirmationPhrase))
        """
    }

    static func result(_ result: AgentCleanupResult) -> String {
        let removedCount = result.items.count { $0.outcome == "removed" }
        return AgentASCIITable.render(
            columns: [
                AgentTableColumn("Removed", alignment: .trailing),
                AgentTableColumn("Failed", alignment: .trailing),
                AgentTableColumn("Blocked", alignment: .trailing),
                AgentTableColumn("Recovered", alignment: .trailing)
            ],
            rows: [[
                String(removedCount),
                String(result.failureCount),
                String(result.blockedCount),
                format(result.permanentlyRemovedBytes)
            ]]
        )
    }

    private static func status(_ candidate: AgentCandidate) -> String {
        if candidate.isActive { return "Active" }
        if candidate.requiresAdditionalConfirmation { return "High risk" }
        if candidate.isRecommended { return "Recommended" }
        return "Review"
    }

    private static func format(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file, allowedUnits: [.kb, .mb, .gb, .tb], spellsOutZero: true))
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacing("'", with: "'\\''"))'"
    }
}
