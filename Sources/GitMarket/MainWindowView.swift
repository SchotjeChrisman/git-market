import AppKit
import GitMarketCore
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @State private var isAddingApp = false
    @State private var isShowingSettings = false
    @State private var appBeingEdited: TrackedApp?

    var body: some View {
        content
            .frame(minWidth: 540, minHeight: 360)
            .toolbar { toolbarButtons }
            .sheet(isPresented: $isAddingApp) { AddAppSheet(model: model) }
            .sheet(isPresented: $isShowingSettings) { SettingsView(model: model) }
            .sheet(item: $appBeingEdited) { AppOptionsSheet(model: model, app: $0) }
            .alert("Different developer", isPresented: teamChangeBinding, presenting: model.teamChangePrompt) { prompt in
                Button("Install Anyway", role: .destructive) {
                    Task { await model.install(prompt.appID, allowSigningTeamChange: true) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text($0.message) }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK") {}
            } message: { Text(model.errorMessage ?? "") }
    }

    @ViewBuilder
    private var content: some View {
        if model.apps.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "shippingbox").font(.system(size: 40)).foregroundStyle(.secondary)
                Text("No apps yet").font(.headline)
                Text("Add a GitHub, Forgejo or GitLab repository with macOS releases.").foregroundStyle(.secondary)
                Button("Add App") { isAddingApp = true }
            }
        } else {
            List {
                ForEach(model.apps) { app in
                    AppRowView(app: app, activity: model.activity[app.id]) {
                        Task { await model.install(app.id) }
                    }
                    .contextMenu { contextMenu(for: app) }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for app: TrackedApp) -> some View {
        Button("Options…") { appBeingEdited = app }
        if let path = app.installedBundlePath {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
        }
        Divider()
        Button("Remove from List") { model.remove(app.id) }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItemGroup {
            Button { isAddingApp = true } label: { Label("Add App", systemImage: "plus") }
            Button { Task { await model.checkAll() } } label: { Label("Check for Updates", systemImage: "arrow.clockwise") }
            if model.updateCount > 0 {
                Button { Task { await model.installAllUpdates() } } label: {
                    Label("Update All (\(model.updateCount))", systemImage: "arrow.down.circle")
                }
            }
            Button { isShowingSettings = true } label: { Label("Settings", systemImage: "gearshape") }
        }
    }

    private var teamChangeBinding: Binding<Bool> {
        Binding(get: { model.teamChangePrompt != nil }, set: { if !$0 { model.teamChangePrompt = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}
