import SwiftUI

struct StorageSummaryCard: View {
    let snapshot: DiskStorageSnapshot?

    var body: some View {
        VStack(alignment: .leading) {
            Label("Mac Storage", systemImage: "internaldrive")
                .font(.title2)
                .bold()

            if let snapshot {
                ProgressView(value: snapshot.usedFraction)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .accessibilityLabel("Mac storage used")
                    .accessibilityValue(snapshot.usedFraction.formatted(.percent.precision(.fractionLength(0))))

                Text("\(ByteCountFormat.string(snapshot.usedBytes)) of \(ByteCountFormat.string(snapshot.totalBytes)) used")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
                Text("Storage capacity will appear after the scan.")
                    .foregroundStyle(.secondary)
            }
        }
        .panelCard()
    }
}
