import SwiftUI

struct DeviceSupportPreference: View {
    @Binding var isEnabled: Bool
    @Binding var minimumAgeDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Automatically select old Device Support")

                    Text("Select iOS and watchOS Device Support that has not been modified for:")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Automatically select old Device Support", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityHint("Controls whether older Device Support is selected after each scan.")
            }

            MinimumAgeRuleRow(
                title: "Older than",
                days: $minimumAgeDays,
                range: 1...730
            )
            .disabled(!isEnabled)

            Text("All Device Support remains visible. Selected files are not deleted until you review and confirm cleanup.")
                .foregroundStyle(.secondary)
        }
    }
}
