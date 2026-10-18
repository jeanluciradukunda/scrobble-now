#if os(iOS)
import SwiftUI

@main
struct ScrobbleNowiOSApp: App {
    @StateObject private var viewModel = NowPlayingViewModel.shared
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var scrobbler = SystemScrobbleService.shared

    init() {
        KeychainService.bootstrapDefaults()
        MPNowPlayingBridge.shared.startListening()

        // Not `viewModel`: a @StateObject read in App.init is a throwaway instance, not the one the views get.
        SystemScrobbleService.shared.onScrobbleSuccess = {
            Task { await NowPlayingViewModel.shared.refresh() }
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NowPlayingView(viewModel: viewModel, settings: settings, scrobbler: scrobbler)
                    .tabItem {
                        Label("Feed", systemImage: "waveform")
                    }

                LibraryView { _, _ in }
                    .tabItem {
                        Label("Library", systemImage: "square.stack")
                    }

                CollageView()
                    .tabItem {
                        Label("Collage", systemImage: "square.grid.3x3")
                    }

                HistoryView { _, _ in }
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                StatisticsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
            }
            .environment(\.appAccent, AppAccent.color(for: settings.accentColorName))
            .tint(AppAccent.color(for: settings.accentColorName))
        }
    }
}
#endif
