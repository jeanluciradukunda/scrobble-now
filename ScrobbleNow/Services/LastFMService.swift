import Foundation
import CryptoKit

actor LastFMService {
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private var apiKey: String { KeychainService.lastfmApiKey }
    private var sharedSecret: String { KeychainService.lastfmSharedSecret }

    // MARK: - Recent Tracks (live feed)

    func getRecentTracks(user: String, limit: Int = 30) async throws -> [ScrobbledTrack] {
        let url = URL(string: "\(baseURL)?method=user.getRecentTracks&user=\(user)&api_key=\(apiKey)&format=json&limit=\(limit)&extended=1")!
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let recentTracks = json?["recenttracks"] as? [String: Any],
              let tracks = recentTracks["track"] as? [[String: Any]] else {
            return []
        }

        return tracks.compactMap { parseTrack($0) }
    }

    // MARK: - Album Info

    func getAlbumInfo(artist: String, album: String, user: String? = nil) async throws -> [String: Any] {
        var urlString = "\(baseURL)?method=album.getInfo&artist=\(artist.urlEncoded)&album=\(album.urlEncoded)&api_key=\(apiKey)&format=json"
        if let user = user { urlString += "&username=\(user)" }
        let url = URL(string: urlString)!
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - User Info

    func getUserInfo(user: String) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)?method=user.getInfo&user=\(user)&api_key=\(apiKey)&format=json")!
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Top Albums

    func getTopAlbums(user: String, period: String = "overall", limit: Int = 50) async throws -> [TopAlbumEntry] {
        let url = URL(string: "\(baseURL)?method=user.getTopAlbums&user=\(user)&period=\(period)&api_key=\(apiKey)&format=json&limit=\(limit)")!
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let topAlbums = json?["topalbums"] as? [String: Any],
              let albums = topAlbums["album"] as? [[String: Any]] else {
            return []
        }

        return albums.compactMap { dict -> TopAlbumEntry? in
            guard let name = dict["name"] as? String,
                  let artist = (dict["artist"] as? [String: Any])?["name"] as? String else { return nil }
            let playcount = Int((dict["playcount"] as? String) ?? "0") ?? 0
            let imageURL = extractImageURL(from: dict)
            let url = URL(string: (dict["url"] as? String) ?? "")
            return TopAlbumEntry(albumName: name, artistName: artist, playcount: playcount, artworkURL: imageURL, lastfmURL: url)
        }
    }

    // MARK: - Top Artists

    func getTopArtists(user: String, period: String = "overall", limit: Int = 50) async throws -> [TopArtistEntry] {
        let url = URL(string: "\(baseURL)?method=user.getTopArtists&user=\(user)&period=\(period)&api_key=\(apiKey)&format=json&limit=\(limit)")!
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let topArtists = json?["topartists"] as? [String: Any],
              let artists = topArtists["artist"] as? [[String: Any]] else {
            return []
        }

        return artists.compactMap { dict -> TopArtistEntry? in
            guard let name = dict["name"] as? String else { return nil }
            let playcount = Int((dict["playcount"] as? String) ?? "0") ?? 0
            let imageURL = extractImageURL(from: dict)
            let url = URL(string: (dict["url"] as? String) ?? "")
            return TopArtistEntry(name: name, playcount: playcount, imageURL: imageURL, lastfmURL: url)
        }
    }

    // MARK: - Auth

    func getAuthToken() async throws -> String {
        let url = URL(string: "\(baseURL)?method=auth.getToken&api_key=\(apiKey)&format=json")!
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["token"] as? String else { throw LastFMError.authFailed }
        return token
    }

    func getSession(token: String) async throws -> (sessionKey: String, username: String) {
        let sig = md5Signature(params: ["api_key": apiKey, "method": "auth.getSession", "token": token])
        let url = URL(string: "\(baseURL)?method=auth.getSession&api_key=\(apiKey)&token=\(token)&api_sig=\(sig)&format=json")!
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let session = json?["session"] as? [String: Any],
              let key = session["key"] as? String,
              let name = session["name"] as? String else {
            throw LastFMError.authFailed
        }
        return (key, name)
    }

    var authURL: String {
        "https://www.last.fm/api/auth/?api_key=\(apiKey)"
    }

    // MARK: - Scrobble / Now Playing

    func updateNowPlaying(artist: String, track: String, album: String) async throws {
        guard let sk = KeychainService.lastfmSessionKey else { return }
        let params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": artist, "track": track, "album": album,
            "api_key": apiKey, "sk": sk
        ]
        try await signedPost(params: params)
    }

    func scrobble(artist: String, track: String, album: String, timestamp: Int) async throws {
        guard let sk = KeychainService.lastfmSessionKey else { return }
        let params: [String: String] = [
            "method": "track.scrobble",
            "artist": artist, "track": track, "album": album,
            "timestamp": String(timestamp),
            "api_key": apiKey, "sk": sk
        ]
        try await signedPost(params: params)
    }

    // MARK: - Helpers

    private func parseTrack(_ dict: [String: Any]) -> ScrobbledTrack? {
        guard let name = dict["name"] as? String,
              let artist = (dict["artist"] as? [String: Any])?["name"] as? String else { return nil }

        let album = (dict["album"] as? [String: Any])?["#text"] as? String ?? ""
        let isNowPlaying = (dict["@attr"] as? [String: Any])?["nowplaying"] as? String == "true"
        let loved = (dict["loved"] as? String) == "1"
        let mbid = dict["mbid"] as? String
        let url = URL(string: (dict["url"] as? String) ?? "")
        let artworkURL = extractImageURL(from: dict)

        let timestamp: Date
        if isNowPlaying {
            timestamp = Date()
        } else if let dateDict = dict["date"] as? [String: Any],
                  let uts = dateDict["uts"] as? String,
                  let ts = TimeInterval(uts) {
            timestamp = Date(timeIntervalSince1970: ts)
        } else {
            timestamp = Date()
        }

        let id = isNowPlaying ? "now-\(name)-\(artist)" : "\(name)-\(artist)-\(Int(timestamp.timeIntervalSince1970))"

        return ScrobbledTrack(
            id: id, name: name, artistName: artist, albumName: album,
            albumArtworkURL: artworkURL, timestamp: timestamp,
            isNowPlaying: isNowPlaying, loved: loved,
            lastfmURL: url, mbid: mbid
        )
    }

    private func extractImageURL(from dict: [String: Any]) -> URL? {
        guard let images = dict["image"] as? [[String: Any]] else { return nil }
        // Prefer extralarge, then large
        for size in ["extralarge", "large", "medium"] {
            if let img = images.first(where: { ($0["size"] as? String) == size }),
               let urlStr = img["#text"] as? String, !urlStr.isEmpty {
                return URL(string: urlStr)
            }
        }
        return nil
    }

    private func md5Signature(params: [String: String]) -> String {
        let sorted = params.sorted { $0.key < $1.key }
        let sigString = sorted.map { "\($0.key)\($0.value)" }.joined() + sharedSecret
        let digest = Insecure.MD5.hash(data: Data(sigString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func signedPost(params: [String: String]) async throws {
        let sig = md5Signature(params: params)
        var allParams = params
        allParams["api_sig"] = sig
        allParams["format"] = "json"

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = allParams.map { "\($0.key)=\($0.value.urlEncoded)" }.joined(separator: "&").data(using: .utf8)

        let (_, response) = try await URLSession.shared.trackedData(for: request, service: "Last.fm")
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LastFMError.requestFailed
        }
    }

    enum LastFMError: LocalizedError {
        case authFailed
        case requestFailed
        var errorDescription: String? {
            switch self {
            case .authFailed: return "Last.fm authentication failed"
            case .requestFailed: return "Last.fm request failed"
            }
        }
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
