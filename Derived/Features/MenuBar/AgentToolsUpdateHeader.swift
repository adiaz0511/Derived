import SwiftUI

struct AgentToolsUpdateHeader: View {
    let title: String
    let version: String?
    let message: String
    let systemImage: String?
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            } else {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.title2)
                .bold()

            if let version {
                Text(version)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
