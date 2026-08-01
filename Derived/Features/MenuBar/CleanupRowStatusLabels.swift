import SwiftUI

struct CleanupRowStatusLabels: View {
    let item: CleanupItem

    var body: some View {
        HStack {
            if item.runtime?.isNewestForPlatform == true {
                Label("Newest Runtime", systemImage: "star.fill")
                    .foregroundStyle(.orange)
            }
            if item.runtime?.isPrerelease == true {
                Label("Beta", systemImage: "testtube.2")
                    .foregroundStyle(.orange)
            }
            if item.isActive {
                Label("Currently Active", systemImage: "bolt.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
        .bold()
    }
}
