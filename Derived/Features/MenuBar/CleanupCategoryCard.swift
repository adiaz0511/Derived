import SwiftUI

struct CleanupCategoryCard: View {
    let category: CleanupCategory
    let model: AppModel
    let onDelete: (CleanupSelectionScope) -> Void
    @State private var isExpanded = false
    @State private var pageIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageSize = 10

    private var items: [CleanupItem] {
        model.itemsByCategory[category] ?? []
    }

    private var totalLabel: String {
        if items.contains(where: { $0.sizeClassification == .apfsCloneLogical }) {
            "\(items.count) clones"
        } else {
            ByteCountFormat.string(items.reduce(0) { $0 + $1.verifiedReclaimableBytes })
        }
    }

    private var selectedBytes: Int64 {
        items.reduce(0) { total, item in
            model.selectedItemIDs.contains(item.id) ? total + item.verifiedReclaimableBytes : total
        }
    }

    private var hasSelectedItems: Bool {
        items.contains { model.selectedItemIDs.contains($0.id) }
    }

    private var pageCount: Int {
        max(1, (items.count + pageSize - 1) / pageSize)
    }

    private var pageItems: ArraySlice<CleanupItem> {
        let safePage = min(pageIndex, pageCount - 1)
        let start = min(safePage * pageSize, items.count)
        let end = min(start + pageSize, items.count)
        return items[start..<end]
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: toggleExpanded) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: DesignMetrics.sectionDisclosureIconWidth)

                        HStack(spacing: DesignMetrics.sectionTitleIconSpacing) {
                            Image(systemName: category.symbolName)
                                .foregroundStyle(.secondary)
                                .imageScale(.medium)
                                .frame(width: DesignMetrics.sectionTitleIconWidth)
                                .accessibilityHidden(true)

                            Text(category.title)
                                .bold()
                        }
                    }
                    .font(.headline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse \(category.title)" : "Expand \(category.title)")

                SectionInfoButton(
                    title: category.title,
                    message: category.summary
                )

                Spacer()

                Text(totalLabel)
                    .foregroundStyle(.secondary)
                    .bold()

                Button("Delete all \(category.title)", systemImage: "trash", action: deleteAll)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(items.isEmpty || model.isCleaning)
            }

            if isExpanded {
                VStack(alignment: .leading) {
                    if items.isEmpty {
                        Text("No \(category.title.lowercased()) found.")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.secondary)
                            .padding(.vertical)
                    } else if category == .xctestDevices {
                    XCTestInlineList(
                        items: items,
                        model: model,
                        onDelete: onDelete
                        )
                    } else {
                        VStack {
                            ForEach(pageItems) { item in
                                CleanupCandidateRow(
                                    item: item,
                                    isSelected: model.selectedItemIDs.contains(item.id),
                                    isPinned: item.runtime.map { model.settingsStore.settings.pinnedRuntimeIDs.contains($0.id) } ?? false,
                                    onSelectionChange: { model.setSelected($0, item: item) },
                                    onPinChange: { runtimeID, pinned in model.settingsStore.setPinned(pinned, runtimeID: runtimeID) }
                                )
                            }
                        }

                        if pageCount > 1 {
                            HStack {
                                Button("Previous", systemImage: "chevron.left", action: previousPage)
                                    .disabled(pageIndex == 0)
                                Spacer()
                                Text("Page \(pageIndex + 1) of \(pageCount)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Next", systemImage: "chevron.right", action: nextPage)
                                    .disabled(pageIndex >= pageCount - 1)
                            }
                        }

                        Button("Delete Selected (\(ByteCountFormat.string(selectedBytes)))", action: deleteSelected)
                            .buttonStyle(.borderedProminent)
                            .disabled(!hasSelectedItems || model.isCleaning)
                    }
                }
                .transition(disclosureTransition)
            }
        }
        .panelCard()
        .onChange(of: items.count) {
            pageIndex = 0
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .panelStressDisclosure)) { notification in
            applyStressDisclosure(notification)
        }
        #endif
    }

    private func toggleExpanded() {
        withAnimation(disclosureAnimation) {
            isExpanded.toggle()
            if !isExpanded {
                pageIndex = 0
            }
        }
    }

    private var disclosureAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .smooth(duration: 0.24)
    }

    private var disclosureTransition: AnyTransition {
        .opacity
    }

    private func deleteAll() {
        onDelete(.allItems(in: category))
    }

    private func deleteSelected() {
        onDelete(.selectedItems(in: category))
    }

    private func previousPage() {
        pageIndex = max(0, pageIndex - 1)
    }

    private func nextPage() {
        pageIndex = min(pageCount - 1, pageIndex + 1)
    }

    #if DEBUG
    private func applyStressDisclosure(_ notification: Notification) {
        guard notification.userInfo?["category"] as? String == category.rawValue,
              let expanded = notification.userInfo?["isExpanded"] as? Bool else { return }
        withAnimation(disclosureAnimation) {
            isExpanded = expanded
            if !expanded {
                pageIndex = 0
            }
        }
    }
    #endif
}
