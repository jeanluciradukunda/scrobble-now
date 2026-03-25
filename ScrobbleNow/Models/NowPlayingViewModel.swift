import SwiftUI

@MainActor
class NowPlayingViewModel: ObservableObject {
    @Published var nowPlaying: ScrobbledTrack?
    @Published var recentTracks: [ScrobbledTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var albumArtwork: PlatformImage?

    private let lastfmService = LastFMService()
    private let cache = CacheService.shared
    private var pollTimer: Timer?

    init() {
        startPolling()
    }

    func startPolling() {
        pollTimer?.invalidate()
        let interval = SettingsManager.shared.pollIntervalSeconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: max(10, interval), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else {
            errorMessage = "No Last.fm username set"
            return
        }

        isLoading = recentTracks.isEmpty
        do {
            let tracks = try await lastfmService.getRecentTracks(user: username, limit: 30)

            let oldNowPlaying = nowPlaying
            recentTracks = tracks
            nowPlaying = tracks.first(where: { $0.isNowPlaying })

            // Load artwork for now playing
            if let np = nowPlaying, np.name != oldNowPlaying?.name,
               let artURL = np.albumArtworkURL {
                let (data, _) = try await URLSession.shared.data(from: artURL)
                albumArtwork = PlatformImage(data: data)
            }

            errorMessage = nil
        } catch {
            if recentTracks.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func forceRefresh() async {
        await refresh()
    }
}
