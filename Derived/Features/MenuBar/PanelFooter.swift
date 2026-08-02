import SwiftUI

struct PanelFooter: View {
    let model: AppModel
    let softwareUpdateController: SoftwareUpdateController
    @State private var launchAtLogin = LaunchAtLoginController()

    var body: some View {
        HStack {
            Button(model.isScanning ? "Scanning…" : "Rescan", systemImage: "arrow.clockwise", action: scan)
                .buttonStyle(.borderedProminent)
                .disabled(model.isScanning)

            Menu("More", systemImage: "ellipsis.circle") {
                Button("Clear Selection", systemImage: "xmark.circle", action: clearSelection)
                    .disabled(model.selectedItemIDs.isEmpty)
                Divider()
                Toggle("Launch at Login", systemImage: "play.circle", isOn: launchAtLoginBinding)
                    .disabled(launchAtLogin.isChanging)
                Divider()
                Button("Check for Updates…", systemImage: "arrow.triangle.2.circlepath", action: checkForUpdates)
                Divider()
                Button("Quit Derived", systemImage: "power", action: quit)
            }
            .menuStyle(.borderlessButton)

            Spacer()

            VStack(alignment: .trailing) {
                Text("Selected: \(ByteCountFormat.string(model.selectedBytes))")
                    .bold()
                if let date = model.report?.scannedAt {
                    Text("Scanned \(date.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
            }

        }
        .padding()
        .background(.bar)
        .alert("Couldn’t Change Login Setting", isPresented: $launchAtLogin.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchAtLogin.errorMessage)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: launchAtLogin.setEnabled
        )
    }

    private func scan() {
        Task { await model.scan() }
    }

    private func clearSelection() {
        model.selectedItemIDs.removeAll()
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func checkForUpdates() {
        softwareUpdateController.checkForUpdates()
    }
}
