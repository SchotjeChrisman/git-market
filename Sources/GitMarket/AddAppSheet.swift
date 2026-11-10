import GitMarketCore
import SwiftUI

struct AddAppSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var repositoryText = ""
    @State private var forgeKind: ForgeKind?
    @State private var needsForgeKind = false
    @State private var isLookingUp = false
    @State private var preview: ReleasePreview?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add App").font(.title2)
            TextField("https://github.com/owner/repository", text: $repositoryText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(lookUp)
                .onChange(of: repositoryText) { _ in resetResult() }
            if needsForgeKind { forgePicker }
            if isLookingUp { ProgressView().controlSize(.small) }
            if let errorText { Text(errorText).foregroundStyle(.red).font(.callout) }
            if let preview { previewSummary(preview) }
            Spacer(minLength: 0)
            buttons
        }
        .padding(20)
        .frame(width: 460, height: 320)
    }

    private var forgePicker: some View {
        Picker("Forge", selection: $forgeKind) {
            Text("Choose…").tag(ForgeKind?.none)
            Text("GitHub / GitHub Enterprise").tag(ForgeKind?.some(.github))
            Text("Forgejo / Gitea / Codeberg").tag(ForgeKind?.some(.forgejo))
            Text("GitLab").tag(ForgeKind?.some(.gitlab))
        }
    }

    private func previewSummary(_ preview: ReleasePreview) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Latest release \(preview.release.tag)").font(.headline)
            Text(preview.asset.name)
            if let size = preview.asset.size {
                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)).foregroundStyle(.secondary)
            }
        }
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
            if let preview {
                Button("Install") {
                    model.addAndInstall(preview)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Look Up", action: lookUp)
                    .disabled(repositoryText.isEmpty || isLookingUp)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func resetResult() {
        preview = nil
        errorText = nil
    }

    private func lookUp() {
        guard !repositoryText.isEmpty, !isLookingUp else { return }
        isLookingUp = true
        errorText = nil
        Task {
            do {
                preview = try await model.preview(repositoryText, kind: forgeKind)
            } catch {
                if case ForgeError.unknownForge = error { needsForgeKind = true }
                errorText = ErrorDescription.text(for: error)
            }
            isLookingUp = false
        }
    }
}
