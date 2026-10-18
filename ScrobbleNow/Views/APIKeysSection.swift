import SwiftUI

struct APIKeysSection: View {
    @State private var usesOwnKey = KeychainService.usesOwnLastfmKey
    @State private var hasLastfmKey = !KeychainService.lastfmApiKey.isEmpty
    @State private var hasDiscogsToken = !KeychainService.discogsToken.isEmpty
    @State private var showAdvanced = false
    @State private var ownKey = KeychainService.get(.ownLastfmApiKey) ?? ""
    @State private var ownSecret = KeychainService.get(.ownLastfmSharedSecret) ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusRow("Last.fm API key", value: lastfmStatus, isOK: hasLastfmKey)
            statusRow("Discogs token", value: hasDiscogsToken ? "Set" : "Not set (optional)", isOK: hasDiscogsToken)

            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Use your own Last.fm API account instead of the app's. Create one at last.fm/api/account/create. Changing the key signs you out of Last.fm.")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    keyField("API key", text: $ownKey)
                    keyField("Shared secret", text: $ownSecret)
                    HStack(spacing: 8) {
                        Button("Save") { save(apiKey: ownKey, secret: ownSecret) }
                            .disabled(ownKey.isEmpty || ownSecret.isEmpty)
                        Button("Use the app's key", role: .destructive) {
                            ownKey = ""
                            ownSecret = ""
                            save(apiKey: "", secret: "")
                        }
                        .disabled(!usesOwnKey)
                    }
                    .font(.system(size: 9, weight: .medium))
                }
                .padding(.top, 4)
            } label: {
                Text("Advanced")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastfmStatus: String {
        guard hasLastfmKey else { return "Missing" }
        return usesOwnKey ? "Your own" : "Built in"
    }

    private func save(apiKey: String, secret: String) {
        KeychainService.setOwnLastfmCredentials(apiKey: apiKey, secret: secret)
        usesOwnKey = KeychainService.usesOwnLastfmKey
        hasLastfmKey = !KeychainService.lastfmApiKey.isEmpty
    }

    private func statusRow(_ title: String, value: String, isOK: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(isOK ? .secondary : Color.red)
            Circle()
                .fill(isOK ? Color.green : Color.red)
                .frame(width: 5, height: 5)
        }
    }

    private func keyField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}
