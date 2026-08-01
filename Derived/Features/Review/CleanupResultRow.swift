import SwiftUI

struct CleanupResultRow: View {
    let result: CleanupItemResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(result.name, systemImage: symbolName)
                    .bold()
                    .foregroundStyle(statusColor)
                Spacer()
                Text(sizeLabel)
                    .foregroundStyle(.secondary)
                    .bold()
            }

            Text(result.path)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Text(result.message)
                .foregroundStyle(.secondary)

            Text(result.operation)
                .font(.callout.monospaced())
                .textSelection(.enabled)
        }
        .panelCard()
    }

    private var sizeLabel: String {
        if let logicalByteCount = result.logicalByteCount {
            return "\(ByteCountFormat.string(logicalByteCount)) logical"
        }
        return ByteCountFormat.string(result.byteCount)
    }

    private var symbolName: String {
        switch result.outcome {
        case .removed: "checkmark.circle"
        case .failed: "xmark.circle"
        case .blocked: "lock.circle"
        }
    }

    private var statusColor: Color {
        switch result.outcome {
        case .removed: .green
        case .failed: .red
        case .blocked: .orange
        }
    }
}
