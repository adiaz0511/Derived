import SwiftUI

struct CleanupReportView: View {
    let report: CleanupReport
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignMetrics.contentSpacing) {
            Text("Cleanup Complete")
                .font(.title2)
                .bold()

            LabeledContent("Permanently Deleted") {
                Text(ByteCountFormat.string(report.permanentlyRemovedBytes))
                    .bold()
            }

            if !report.activeProcesses.isEmpty {
                Label("Active during cleanup: \(report.activeProcesses.joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if let historyError = report.historyError {
                Label("Cleanup finished, but history could not be saved: \(historyError)", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            Text("\(report.successfulResults.count) completed · \(report.failureCount) failed · \(report.blockedCount) blocked")
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: DesignMetrics.contentSpacing) {
                    ForEach(report.results) { result in
                        CleanupResultRow(result: result)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
