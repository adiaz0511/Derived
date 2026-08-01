import SwiftUI

struct PathBreadcrumb: View {
    let path: String

    private var location: String {
        PathDisplayFormat.location(for: path)
    }

    var body: some View {
        Label {
            Text(location)
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: "folder")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .help(path)
        .accessibilityLabel("Location: \(location)")
        .accessibilityHint(path)
    }
}
