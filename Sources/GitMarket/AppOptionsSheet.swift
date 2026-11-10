import GitMarketCore
import SwiftUI

struct AppOptionsSheet: View {
    @ObservedObject var model: AppModel
    let app: TrackedApp
    @Environment(\.dismiss) private var dismiss

    @State private var includePrereleases: Bool
    @State private var assetNamePattern: String
    @State private var errorText: String?

    init(model: AppModel, app: TrackedApp) {
        self.model = model
        self.app = app
        _includePrereleases = State(initialValue: app.includePrereleases)
        _assetNamePattern = State(initialValue: app.assetNamePattern ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(app.displayName).font(.title2)
            Toggle("Include pre-releases", isOn: $includePrereleases)
            VStack(alignment: .leading, spacing: 4) {
                Text("Asset name pattern (regular expression)")
                TextField("Leave empty to choose automatically", text: $assetNamePattern)
                    .textFieldStyle(.roundedBorder)
                Text("Use this when the automatic choice picks the wrong file.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let errorText { Text(errorText).foregroundStyle(.red).font(.callout) }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save", action: save).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 260)
    }

    private func save() {
        let pattern = assetNamePattern.isEmpty ? nil : assetNamePattern
        do {
            _ = try AssetSelector(namePattern: pattern)
        } catch {
            errorText = ErrorDescription.text(for: error)
            return
        }
        model.updateOptions(of: app.id, includePrereleases: includePrereleases, assetNamePattern: pattern)
        dismiss()
    }
}
