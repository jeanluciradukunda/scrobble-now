import Foundation

actor MusicBrainzService {
    private let userAgent = "ScrobbleNow/1.0 (https://github.com/jeanluciradukunda/scrobble-now)"

    // MARK: - Search Release Groups

    func searchAlbum(album: String, artist: String) async throws -> [MBReleaseGroup] {
        let query = "\(album) AND artist:\(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://musicbrainz.org/ws/2/release-group/?query=\(query)&fmt=json&limit=5")!

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        // Rate limit — MB allows 1 req/sec
        try? await Task.sleep(for: .milliseconds(300))

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let groups = json?["release-groups"] as? [[String: Any]] else { return [] }

        return groups.compactMap { dict -> MBReleaseGroup? in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String else { return nil }
            let artist = (dict["artist-credit"] as? [[String: Any]])?.first?["name"] as? String ?? ""
            let firstRelease = dict["first-release-date"] as? String
            let year = firstRelease.flatMap { str -> Int? in
                guard str.count >= 4 else { return nil }
                return Int(str.prefix(4))
            }
            return MBReleaseGroup(id: id, title: title, artist: artist, year: year)
        }
    }

    // MARK: - Get Tracks from Release

    func getReleaseTracks(releaseGroupId: String) async throws -> [AlbumTrack] {
        // First get releases in the group
        let url = URL(string: "https://musicbrainz.org/ws/2/release?release-group=\(releaseGroupId)&fmt=json&limit=1")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        try? await Task.sleep(for: .milliseconds(300))
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let releases = json?["releases"] as? [[String: Any]],
              let releaseId = releases.first?["id"] as? String else { return [] }

        // Now get tracks
        let trackURL = URL(string: "https://musicbrainz.org/ws/2/release/\(releaseId)?inc=recordings&fmt=json")!
        var trackRequest = URLRequest(url: trackURL)
        trackRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        try? await Task.sleep(for: .milliseconds(300))
        let (trackData, _) = try await URLSession.shared.data(for: trackRequest)
        let trackJson = try JSONSerialization.jsonObject(with: trackData) as? [String: Any]

        guard let media = trackJson?["media"] as? [[String: Any]] else { return [] }

        var tracks: [AlbumTrack] = []
        for medium in media {
            guard let recordings = medium["tracks"] as? [[String: Any]] else { continue }
            for rec in recordings {
                guard let title = (rec["recording"] as? [String: Any])?["title"] as? String ?? rec["title"] as? String else { continue }
                let position = rec["position"] as? Int ?? rec["number"] as? Int ?? tracks.count + 1
                let lengthMs = (rec["recording"] as? [String: Any])?["length"] as? Int ?? rec["length"] as? Int ?? 0
                tracks.append(AlbumTrack(name: title, artistName: "", durationMs: lengthMs, trackNumber: position, previewURL: nil, userPlaycount: nil))
            }
        }
        return tracks
    }

    // MARK: - Cover Art

    nonisolated func getCoverArtURL(releaseGroupId: String) -> URL? {
        URL(string: "https://coverartarchive.org/release-group/\(releaseGroupId)/front-500")
    }

    struct MBReleaseGroup {
        let id: String
        let title: String
        let artist: String
        let year: Int?
    }
}
