import Foundation

actor DiscogsService {
    private var token: String { KeychainService.discogsToken }
    private let userAgent = "ScrobbleNow/1.0 (https://github.com/jeanluciradukunda/scrobble-now)"

    struct SearchResult {
        let releaseId: Int
        let title: String
        let year: String?
        let coverURL: URL?
        let resourceURL: String
    }

    struct ReleaseDetail {
        let title: String
        let artist: String
        let year: Int?
        let artworkURLs: [URL]
        let tracks: [AlbumTrack]
        let genres: [String]
        let styles: [String]
        let discogsURL: URL?
    }

    // MARK: - Search

    func searchRelease(album: String, artist: String) async throws -> [SearchResult] {
        let query = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://api.discogs.com/database/search?q=\(query)&type=release&per_page=5&token=\(token)")!

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.trackedData(for: request, service: "Discogs")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let results = json?["results"] as? [[String: Any]] else { return [] }

        return results.compactMap { dict -> SearchResult? in
            guard let id = dict["id"] as? Int,
                  let title = dict["title"] as? String else { return nil }
            let year = dict["year"] as? String
            let thumbStr = dict["cover_image"] as? String ?? dict["thumb"] as? String
            let coverURL = thumbStr.flatMap { URL(string: $0) }
            let resourceURL = dict["resource_url"] as? String ?? ""
            return SearchResult(releaseId: id, title: title, year: year, coverURL: coverURL, resourceURL: resourceURL)
        }
    }

    // MARK: - Release Detail (tracks + all images)

    func getReleaseDetail(id: Int) async throws -> ReleaseDetail? {
        let url = URL(string: "https://api.discogs.com/releases/\(id)?token=\(token)")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        // Rate limit — Discogs allows 60/min
        try? await Task.sleep(for: .milliseconds(200))

        let (data, _) = try await URLSession.shared.trackedData(for: request, service: "Discogs")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json = json else { return nil }

        let title = json["title"] as? String ?? ""
        let artists = (json["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? ""
        let year = json["year"] as? Int
        let genres = json["genres"] as? [String] ?? []
        let styles = json["styles"] as? [String] ?? []
        let uri = json["uri"] as? String
        let discogsURL = uri.flatMap { URL(string: "https://www.discogs.com\($0)") }

        // All images
        let images = (json["images"] as? [[String: Any]]) ?? []
        let artworkURLs = images.compactMap { img -> URL? in
            let urlStr = img["resource_url"] as? String ?? img["uri"] as? String ?? ""
            return URL(string: urlStr)
        }

        // Tracklist
        let tracklist = (json["tracklist"] as? [[String: Any]]) ?? []
        let tracks = tracklist.enumerated().compactMap { (i, t) -> AlbumTrack? in
            guard let name = t["title"] as? String else { return nil }
            let duration = t["duration"] as? String ?? ""
            let ms = parseDuration(duration)
            return AlbumTrack(name: name, artistName: artists, durationMs: ms, trackNumber: i + 1, previewURL: nil, userPlaycount: nil)
        }

        return ReleaseDetail(title: title, artist: artists, year: year, artworkURLs: artworkURLs, tracks: tracks, genres: genres, styles: styles, discogsURL: discogsURL)
    }

    private func parseDuration(_ str: String) -> Int {
        let parts = str.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 { return (parts[0] * 60 + parts[1]) * 1000 }
        if parts.count == 3 { return (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000 }
        return 0
    }
}
