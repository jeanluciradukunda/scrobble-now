import SwiftUI

@main
struct ScrobbleNowApp: App {
    @StateObject private var viewModel = NowPlayingViewModel()
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var scrobbler = SystemScrobbleService.shared

    init() {
        KeychainService.bootstrapDefaults()
        MediaRemoteBridge.shared.startListening()

        // Refresh history feed immediately after a successful scrobble
        let vm = viewModel
        SystemScrobbleService.shared.onScrobbleSuccess = {
            Task { await vm.refresh() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            NowPlayingView(viewModel: viewModel, settings: settings, scrobbler: scrobbler)
                .frame(width: 320, height: 580)
                .environment(\.appAccent, AppAccent.color(for: settings.accentColorName))
                .tint(AppAccent.color(for: settings.accentColorName))
        } label: {
            MenuBarLabel(viewModel: viewModel, settings: settings, bridge: MediaRemoteBridge.shared)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var viewModel: NowPlayingViewModel
    @ObservedObject var settings: SettingsManager
    @ObservedObject var bridge: MediaRemoteBridge

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: bridge.isPlaying ? "waveform" : "waveform")
                .renderingMode(.template)
                .symbolEffect(.variableColor.iterative, isActive: bridge.isPlaying)
            if settings.showTitleInMenuBar {
                if let sysTrack = bridge.currentTrack, bridge.isPlaying {
                    // Show system Now Playing (most responsive)
                    Text("\(sysTrack.artist) — \(sysTrack.title)")
                        .lineLimit(1)
                } else if let track = viewModel.nowPlaying {
                    // Fallback to Last.fm
                    Text("\(track.artistName) — \(track.name)")
                        .lineLimit(1)
                }
            }
        }
    }
}
