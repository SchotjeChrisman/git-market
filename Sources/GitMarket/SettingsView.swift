import GitMarketCore
import SwiftUI

struct SettingsView: View {
    private static let intervalChoices = [1, 3, 6, 12, 24]

    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.title2)
            Picker("Check for updates every", selection: $model.checkIntervalHours) {
                ForEach(Self.intervalChoices, id: \.self) { Text($0 == 1 ? "hour" : "\($0) hours").tag($0) }
            }
            tokenSection
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 360)
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Access tokens").font(.headline)
            Text("Optional. They raise rate limits and let release lists of private repositories load; private downloads are not supported yet. Stored in the macOS Keychain.")
                .font(.caption).foregroundStyle(.secondary)
            if model.hosts.isEmpty {
                Text("Add an app first; its host will show up here.").foregroundStyle(.secondary)
            }
            ForEach(model.hosts, id: \.self) { TokenRow(host: $0) }
        }
    }
}

private struct TokenRow: View {
    let host: String
    private let keychain = KeychainTokenStore()

    @State private var token = ""
    @State private var hasStoredToken = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(host).frame(width: 130, alignment: .leading)
                SecureField(hasStoredToken ? "Token saved" : "Token", text: $token)
                Button("Save", action: save).disabled(token.isEmpty)
                Button("Remove", action: remove).disabled(!hasStoredToken)
            }
            if let errorText { Text(errorText).font(.caption).foregroundStyle(.red) }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        do {
            hasStoredToken = try keychain.token(for: host) != nil
        } catch {
            errorText = "Keychain: \(error)"
        }
    }

    private func save() {
        do {
            try keychain.save(token, for: host)
            token = ""
            errorText = nil
            refresh()
        } catch {
            errorText = "Keychain: \(error)"
        }
    }

    private func remove() {
        do {
            try keychain.delete(host: host)
            errorText = nil
            refresh()
        } catch {
            errorText = "Keychain: \(error)"
        }
    }
}
