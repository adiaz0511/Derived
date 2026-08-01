import SwiftUI

struct MinimumAgeRuleRow: View {
    let title: String
    @Binding var days: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)

            Spacer()

            Stepper(value: $days, in: range) {
                Text("\(days) days")
                    .monospacedDigit()
            }
            .fixedSize()
        }
    }
}
