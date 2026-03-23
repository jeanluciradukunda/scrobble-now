import SwiftUI

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var topAlbums: [TopAlbumEntry] = []
    @Published var topArtists: [TopArtistEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod: String = "7day"
    @Published var mode: LibraryMode = .albums

    enum LibraryMode: String, CaseIterable {
        case albums = "Albums"
        case artists = "Artists"
    }

    static let periods: [(label: String, value: String)] = [
        ("7 Days", "7day"),
        ("1 Month", "1month"),
        ("3 Months", "3month"),
        ("6 Months", "6month"),
        ("12 Months", "12month"),
        ("All Time", "overall"),
    ]

    private let lastfm = LastFMService()

    func load() async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else {
            errorMessage = "No username set"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let albums = lastfm.getTopAlbums(user: username, period: selectedPeriod, limit: 50)
            async let artists = lastfm.getTopArtists(user: username, period: selectedPeriod, limit: 50)

            topAlbums = try await albums
            topArtists = try await artists
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await load()
    }
}
