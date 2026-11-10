import AppKit
import GitMarketCore
import SwiftUI

struct AppRowView: View {
    let app: TrackedApp
    let activity: Activity?
    let install: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName).font(.headline)
                Text(versionLine).font(.caption).foregroundStyle(.secondary)
                Text(app.location.displayName).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var icon: some View {
        if let path = app.installedBundlePath, FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable()
        } else {
            Image(systemName: "shippingbox").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }

    private var versionLine: String {
        guard let installed = app.installedTag else {
            guard let latest = app.latestKnownTag else { return "Not installed, no release yet" }
            return "Not installed, \(latest) available"
        }
        if app.hasUpdate, let latest = app.latestKnownTag { return "\(installed) → \(latest)" }
        return "Installed \(installed)"
    }

    @ViewBuilder
    private var trailing: some View {
        switch activity {
        case .checking:
            HStack { ProgressView().controlSize(.small); Text("Checking").font(.caption) }
        case .installing:
            HStack { ProgressView().controlSize(.small); Text("Installing").font(.caption) }
        case .failed(let message):
            HStack {
                Label("Failed", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red).help(message)
                Button("Retry", action: install)
            }
        case nil:
            idleAction
        }
    }

    @ViewBuilder
    private var idleAction: some View {
        if app.installedTag == nil {
            Button("Install", action: install)
        } else if app.hasUpdate {
            Button("Update", action: install).buttonStyle(.borderedProminent)
        } else {
            Text("Up to date").font(.caption).foregroundStyle(.secondary)
        }
    }
}
