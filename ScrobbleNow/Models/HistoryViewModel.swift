import SwiftUI

struct DayGroup: Identifiable {
    let id: String // "2026-03-23"
    let date: Date
    let tracks: [ScrobbledTrack]

    var displayDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var totalScrobbles: Int { tracks.count }

    var uniqueArtists: Int {
        Set(tracks.map { $0.artistName.lowercased() }).count
    }

    var uniqueAlbums: Int {
        Set(tracks.map { $0.albumName.lowercased() }).count
    }
}

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var dayGroups: [DayGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let lastfm = LastFMService()

    func load() async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else {
            errorMessage = "No username set"
            return
        }

        isLoading = dayGroups.isEmpty
        do {
            // Fetch last 200 scrobbles for history
            let tracks = try await lastfm.getRecentTracks(user: username, limit: 200)

            let cal = Calendar.current
            var grouped: [String: [ScrobbledTrack]] = [:]
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"

            for track in tracks where !track.isNowPlaying {
                let key = df.string(from: track.timestamp)
                grouped[key, default: []].append(track)
            }

            dayGroups = grouped.map { key, tracks in
                let date = df.date(from: key) ?? Date()
                return DayGroup(id: key, date: date, tracks: tracks)
            }
            .sorted { $0.date > $1.date }

            errorMessage = nil
        } catch {
            if dayGroups.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }
}
