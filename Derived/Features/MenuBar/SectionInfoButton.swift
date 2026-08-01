import SwiftUI

struct SectionInfoButton: View {
    let title: String
    let message: String
    @State private var isPresented = false

    var body: some View {
        Button("About \(title)", systemImage: "info.circle", action: showPopover)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .bold()

                    Text(message)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(width: 280, alignment: .leading)
            }
    }

    private func showPopover() {
        isPresented = true
    }
}
