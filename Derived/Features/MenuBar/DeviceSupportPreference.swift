import SwiftUI

struct DeviceSupportPreference: View {
    @Binding var isEnabled: Bool
    @Binding var minimumAgeDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preselect old Device Support")

                    Text("During the next scan, preselect iOS and watchOS support files older than the minimum age.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Preselect old Device Support", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if isEnabled {
                MinimumAgeRuleRow(
                    title: "Device Support minimum age",
                    days: $minimumAgeDays,
                    range: 1...730
                )
            }
        }
    }
}
