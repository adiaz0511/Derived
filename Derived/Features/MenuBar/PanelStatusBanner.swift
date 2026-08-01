import SwiftUI

struct PanelStatusBanner: View {
    let report: ScanReport?

    var body: some View {
        if let report, !report.activeProcesses.isEmpty || !report.warnings.isEmpty {
            VStack(alignment: .leading) {
                if !report.activeProcesses.isEmpty {
                    Label("Active: \(report.activeProcesses.joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                ForEach(report.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .panelCard()
        }
    }
}
