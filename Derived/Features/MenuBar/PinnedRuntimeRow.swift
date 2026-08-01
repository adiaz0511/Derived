import SwiftUI

struct PinnedRuntimeRow: View {
    let runtime: RuntimeInformation
    let isPinned: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack {
            Label(runtime.name, systemImage: runtime.platform.symbolName)

            Spacer()

            Toggle("Pin \(runtime.name)", isOn: selectionBinding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionBinding: Binding<Bool> {
        Binding(get: { isPinned }, set: onChange)
    }
}
