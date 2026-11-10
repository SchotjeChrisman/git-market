import AppKit
import GitMarketCore
import SwiftUI

enum MainWindow {
    static let id = "main"
}

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private var updatable: [TrackedApp] { model.apps.filter { $0.hasUpdate || $0.isInstallable } }

    var body: some View {
        Button("Open \(AppIdentity.displayName)") {
            openWindow(id: MainWindow.id)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Button("Check for Updates") { Task { await model.checkAll() } }

        if !updatable.isEmpty {
            Divider()
            ForEach(updatable) { app in
                Button("\(app.isInstallable ? "Install" : "Update") \(app.displayName) \(app.latestKnownTag ?? "")") {
                    Task { await model.install(app.id) }
                }
            }
            Button("Update All") { Task { await model.installAllUpdates() } }
        }

        Divider()
        Button("Quit \(AppIdentity.displayName)") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
