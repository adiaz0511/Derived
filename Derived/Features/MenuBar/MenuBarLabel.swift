import SwiftUI

struct MenuBarLabel: View {
    let reclaimableBytes: Int64

    var body: some View {
        Image(systemName: "hammer.fill")
            .accessibilityLabel("Derived, \(ByteCountFormat.string(reclaimableBytes)) reclaimable")
    }
}
