import SwiftUI

struct ArtistBar: Identifiable {
    let id = UUID()
    let name: String
    let playcount: Int
    let fraction: Double // 0-1 relative to top artist
}

struct GenreSlice: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let fraction: Double
}

@MainActor
class StatisticsViewModel: ObservableObject {
    @Published var totalScrobbles: Int = 0
    @Published var registeredDate: String = ""
    @Published var topArtistBars: [ArtistBar] = []
    @Published var genreSlices: [GenreSlice] = []
    @Published var scrobblesToday: Int = 0
    @Published var scrobblesThisWeek: Int = 0
    @Published var isLoading = false

    private let lastfm = LastFMService()

    func load() async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else { return }

        isLoading = true
        do {
            // User info
            let info = try await lastfm.getUserInfo(user: username)
            if let user = info["user"] as? [String: Any] {
                totalScrobbles = Int(user["playcount"] as? String ?? "0") ?? 0
                if let reg = user["registered"] as? [String: Any],
                   let uts = reg["unixtime"] as? String,
                   let ts = TimeInterval(uts) {
                    let date = Date(timeIntervalSince1970: ts)
                    let df = DateFormatter()
                    df.dateFormat = "MMM d, yyyy"
                    registeredDate = df.string(from: date)
                }
            }

            // Top artists (7 day) for bar chart
            let artists = try await lastfm.getTopArtists(user: username, period: "7day", limit: 10)
            let maxPlays = artists.first?.playcount ?? 1
            topArtistBars = artists.map { a in
                ArtistBar(name: a.name, playcount: a.playcount, fraction: Double(a.playcount) / Double(max(1, maxPlays)))
            }

            // Top albums for genre extraction (use tags from Last.fm)
            let albums = try await lastfm.getTopAlbums(user: username, period: "7day", limit: 20)
            var tagCounts: [String: Int] = [:]
            for album in albums.prefix(10) {
                let albumInfo = try? await lastfm.getAlbumInfo(artist: album.artistName, album: album.albumName)
                if let tags = ((albumInfo?["album"] as? [String: Any])?["tags"] as? [String: Any])?["tag"] as? [[String: Any]] {
                    for tag in tags {
                        if let name = tag["name"] as? String {
                            tagCounts[name.lowercased(), default: 0] += 1
                        }
                    }
                }
            }
            let maxTag = tagCounts.values.max() ?? 1
            genreSlices = tagCounts.sorted { $0.value > $1.value }.prefix(8).map { name, count in
                GenreSlice(name: name.capitalized, count: count, fraction: Double(count) / Double(max(1, maxTag)))
            }

            // Recent scrobbles for today/week counts
            let recent = try await lastfm.getRecentTracks(user: username, limit: 200)
            let cal = Calendar.current
            scrobblesToday = recent.filter { !$0.isNowPlaying && cal.isDateInToday($0.timestamp) }.count
            let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            scrobblesThisWeek = recent.filter { !$0.isNowPlaying && $0.timestamp >= weekAgo }.count

        } catch {
            print("Stats load error: \(error)")
        }
        isLoading = false
    }
}
