import SwiftUI

@main
struct ScrobbleNowApp: App {
    @StateObject private var viewModel = NowPlayingViewModel()
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var scrobbler = SystemScrobbleService.shared

    init() {
        KeychainService.bootstrapDefaults()
        MediaRemoteBridge.shared.startListening()
    }

    var body: some Scene {
        MenuBarExtra {
            NowPlayingView(viewModel: viewModel, settings: settings, scrobbler: scrobbler)
                .frame(width: 320, height: 580)
                .environment(\.appAccent, AppAccent.color(for: settings.accentColorName))
                .tint(AppAccent.color(for: settings.accentColorName))
        } label: {
            MenuBarLabel(viewModel: viewModel, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var viewModel: NowPlayingViewModel
    @ObservedObject var settings: SettingsManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
                .renderingMode(.template)
            if let track = viewModel.nowPlaying, settings.showTitleInMenuBar {
                Text("\(track.artistName) — \(track.name)")
                    .lineLimit(1)
            }
        }
    }
}
