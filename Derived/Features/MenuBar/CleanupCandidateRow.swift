import SwiftUI

struct CleanupCandidateRow: View {
    let item: CleanupItem
    let isSelected: Bool
    let isPinned: Bool
    let onSelectionChange: (Bool) -> Void
    let onPinChange: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Toggle("Select \(item.name)", isOn: selectionBinding)
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.name)
                    .layoutPriority(1)

                if item.hasOperationalStatus {
                    CleanupRowStatusLabels(item: item)
                        .fixedSize()
                }

                Spacer()

                Text(sizeLabel)
                    .foregroundStyle(.secondary)
                    .bold()
                    .fixedSize()
            }

            PathBreadcrumb(path: item.path)
                .padding(.leading, 22)

            if let runtime = item.runtime {
                Button(isPinned ? "Unpin Runtime" : "Pin Runtime", systemImage: isPinned ? "pin.fill" : "pin", action: { onPinChange(runtime.id, !isPinned) })
                    .buttonStyle(.plain)
                    .foregroundStyle(isPinned ? .blue : .secondary)
                    .padding(.leading, 22)
            }
        }
        .padding(.vertical, 5)
    }

    private var selectionBinding: Binding<Bool> {
        Binding(get: { isSelected }, set: onSelectionChange)
    }

    private var sizeLabel: String {
        let size = ByteCountFormat.string(item.byteCount)
        return item.sizeClassification == .apfsCloneLogical ? "\(size) logical" : size
    }

}

private extension CleanupItem {
    var hasOperationalStatus: Bool {
        runtime?.isNewestForPlatform == true ||
            runtime?.isPrerelease == true ||
            isActive
    }
}
