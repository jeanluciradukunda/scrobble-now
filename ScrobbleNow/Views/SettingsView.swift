import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var viewModel: NowPlayingViewModel
    @State private var usernameInput: String = ""
    @State private var isAuthenticating = false
    @State private var authError: String?

    private let lastfmService = LastFMService()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("SETTINGS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // MARK: - Account
                sectionHeader("Account")

                if settings.lastfmUsername.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your Last.fm username to see your scrobbles.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            TextField("Username", text: $usernameInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(.ultraThinMaterial)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                                        }
                                }

                            Button("Connect") {
                                let trimmed = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                settings.lastfmUsername = trimmed
                                viewModel.startPolling()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppAccent.current, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppAccent.current)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(settings.lastfmUsername)
                                .font(.system(size: 12, weight: .bold))
                            Text("Connected to Last.fm")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Disconnect") {
                            settings.lastfmUsername = ""
                            KeychainService.delete(.lastfmSessionKey)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.red)
                    }
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.04))
                    }

                    // Full auth (optional — for scrobbling back)
                    if KeychainService.lastfmSessionKey == nil {
                        Button {
                            Task { await authenticate() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 8))
                                Text(isAuthenticating ? "Waiting..." : "Authorize Scrobbling")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(AppAccent.current)
                        }
                        .buttonStyle(.plain)
                        .disabled(isAuthenticating)

                        if let err = authError {
                            Text(err)
                                .font(.system(size: 8))
                                .foregroundStyle(.red)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.green)
                            Text("Scrobbling authorized")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider().opacity(0.2)

                // MARK: - General
                sectionHeader("General")

                Toggle("Show track in menu bar", isOn: $settings.showTitleInMenuBar)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                Toggle("Notify on new track", isOn: $settings.notifyNewTrack)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                HStack {
                    Text("Poll interval")
                        .font(.system(size: 10))
                    Spacer()
                    Text("\(Int(settings.pollIntervalSeconds))s")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.pollIntervalSeconds, in: 10...60, step: 5)
                        .frame(maxWidth: 100)
                        .controlSize(.mini)
                }

                Divider().opacity(0.2)

                // MARK: - Scrobble Behavior
                sectionHeader("Scrobble Behavior")

                Toggle("Enable scrobbling", isOn: $settings.scrobbleEnabled)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                HStack {
                    Text("Scrobble at")
                        .font(.system(size: 10))
                    Spacer()
                    Text("\(Int(settings.scrobbleThresholdPercent))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.scrobbleThresholdPercent, in: 25...90, step: 5)
                        .frame(maxWidth: 100)
                        .controlSize(.mini)
                }

                HStack {
                    Text("Min track duration")
                        .font(.system(size: 10))
                    Spacer()
                    Text("\(settings.minTrackDuration)s")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { Double(settings.minTrackDuration) },
                        set: { settings.minTrackDuration = Int($0) }
                    ), in: 10...120, step: 10)
                        .frame(maxWidth: 100)
                        .controlSize(.mini)
                }

                Toggle("Filter podcasts", isOn: $settings.filterPodcasts)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                Toggle("Album guessing (fill from Last.fm)", isOn: $settings.albumGuessing)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                Toggle("Scrobble notifications", isOn: $settings.scrobbleNotifications)
                    .font(.system(size: 10))
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                // Scrobble stats
                HStack(spacing: 12) {
                    VStack(spacing: 1) {
                        Text("\(SystemScrobbleService.shared.totalScrobbled)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppAccent.current)
                        Text("scrobbled")
                            .font(.system(size: 7))
                            .foregroundStyle(.quaternary)
                    }
                    Spacer()
                    VStack(spacing: 1) {
                        Text("\(SystemScrobbleService.shared.connectors.count)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Text("sources")
                            .font(.system(size: 7))
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(.vertical, 4)

                Divider().opacity(0.2)

                // MARK: - App Connectors
                sectionHeader("Sources")

                if SystemScrobbleService.shared.connectors.isEmpty {
                    Text("Play music from any app to discover sources")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(SystemScrobbleService.shared.connectors) { connector in
                        HStack(spacing: 6) {
                            if let icon = MediaRemoteBridge.shared.appIcon(for: connector.bundleId) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            } else {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.quaternary)
                                    .frame(width: 14, height: 14)
                            }
                            Text(connector.displayName)
                                .font(.system(size: 10))
                                .lineLimit(1)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { connector.enabled },
                                set: { _ in SystemScrobbleService.shared.toggleConnector(bundleId: connector.bundleId) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                        }
                    }
                }

                Divider().opacity(0.2)

                // MARK: - Appearance
                sectionHeader("Appearance")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                    ForEach(AppAccent.options) { option in
                        Button {
                            settings.accentColorName = option.id
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 20, height: 20)
                                .overlay {
                                    if settings.accentColorName == option.id {
                                        Circle().strokeBorder(.white, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(option.name)
                    }
                }

                Divider().opacity(0.2)

                // MARK: - API Keys (developer)
                if settings.developerMode {
                    sectionHeader("API Keys")
                    ForEach(KeychainService.Key.allCases.filter(\.isUserEditable), id: \.rawValue) { key in
                        apiKeyRow(key: key)
                    }
                }

                // Developer mode toggle
                Toggle("Developer mode", isOn: $settings.developerMode)
                    .font(.system(size: 9))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 8)

                // Quit
                HStack {
                    Spacer()
                    Button("Quit Scrobble Now") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.red)
                    Spacer()
                }
            }
            .padding(16)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(.tertiary)
    }

    private func apiKeyRow(key: KeychainService.Key) -> some View {
        HStack {
            Text(key.displayName)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
            let val = KeychainService.get(key) ?? ""
            Text(val.isEmpty ? "Missing" : "Set")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(val.isEmpty ? .red : .green)
        }
    }

    private func authenticate() async {
        isAuthenticating = true
        authError = nil
        do {
            let token = try await lastfmService.getAuthToken()
            let authURL = await lastfmService.authURL + "&token=\(token)"
            if let url = URL(string: authURL) {
                NSWorkspace.shared.open(url)
            }

            // Wait for user to authorize in browser, then get session
            try await Task.sleep(for: .seconds(15))

            let (sessionKey, username) = try await lastfmService.getSession(token: token)
            KeychainService.set(.lastfmSessionKey, value: sessionKey)
            settings.lastfmUsername = username
            viewModel.startPolling()
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }
}
