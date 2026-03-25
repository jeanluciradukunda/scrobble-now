#if os(iOS)
import SwiftUI

@main
struct ScrobbleNowiOSApp: App {
    @StateObject private var viewModel = NowPlayingViewModel()
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var scrobbler = SystemScrobbleService.shared

    init() {
        KeychainService.bootstrapDefaults()
        MPNowPlayingBridge.shared.startListening()

        let vm = viewModel
        SystemScrobbleService.shared.onScrobbleSuccess = {
            Task { await vm.refresh() }
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
