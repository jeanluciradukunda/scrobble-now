import Foundation
import CryptoKit

actor LastFMService {
    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private var apiKey: String { KeychainService.lastfmApiKey }
    private var sharedSecret: String { KeychainService.lastfmSharedSecret }
    private let sessionKey: @Sendable () -> String?
    private let invalidateSession: @Sendable () -> Void

    init(
        sessionKey: @escaping @Sendable () -> String? = { KeychainService.lastfmSessionKey },
        invalidateSession: @escaping @Sendable () -> Void = { KeychainService.delete(.lastfmSessionKey) }
    ) {
        self.sessionKey = sessionKey
        self.invalidateSession = invalidateSession
    }

    // MARK: - Recent Tracks (live feed)

    func getRecentTracks(
        user: String, limit: Int = 30, from start: Date? = nil, to end: Date? = nil, page: Int = 1
    ) async throws -> [ScrobbledTrack] {
        var params = Self.recentTracksParams(user: user, limit: limit, from: start, to: end)
        if page > 1 { params["page"] = String(page) }
        let url = try requestURL(params)
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let recentTracks = json?["recenttracks"] as? [String: Any],
              let tracks = recentTracks["track"] as? [[String: Any]] else {
            return []
        }

        return tracks.compactMap { parseTrack($0) }
    }

    /// Last.fm returns at most 200 tracks a page, so a busy month needs several pages.
    func getAllRecentTracks(user: String, from start: Date, to end: Date, maxPages: Int = 10) async throws -> [ScrobbledTrack] {
        var all: [ScrobbledTrack] = []
        for page in 1...maxPages {
            let tracks = try await getRecentTracks(user: user, limit: 200, from: start, to: end, page: page)
                .filter { !$0.isNowPlaying }
            all += tracks
            if tracks.count < 200 { break }
        }
        return all
    }

    // MARK: - Album Info

    func getAlbumInfo(artist: String, album: String, user: String? = nil) async throws -> [String: Any] {
        var params = ["method": "album.getInfo", "artist": artist, "album": album]
        if let user = user { params["username"] = user }
        let url = try requestURL(params)
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - User Info

    func getUserInfo(user: String) async throws -> [String: Any] {
        let url = try requestURL(["method": "user.getInfo", "user": user])
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Top Albums

    func getTopAlbums(user: String, period: String = "overall", limit: Int = 50) async throws -> [TopAlbumEntry] {
        let url = try requestURL(["method": "user.getTopAlbums", "user": user, "period": period, "limit": String(limit)])
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let topAlbums = json?["topalbums"] as? [String: Any],
              let albums = topAlbums["album"] as? [[String: Any]] else {
            return []
        }

        let entries = albums.compactMap { dict -> TopAlbumEntry? in
            guard let name = dict["name"] as? String,
                  let artist = (dict["artist"] as? [String: Any])?["name"] as? String else { return nil }
            let playcount = Int((dict["playcount"] as? String) ?? "0") ?? 0
            let imageURL = extractImageURL(from: dict)
            let url = URL(string: (dict["url"] as? String) ?? "")
            return TopAlbumEntry(albumName: name, artistName: artist, playcount: playcount, artworkURL: imageURL, lastfmURL: url)
        }
        return AlbumNormalisation.mergingDuplicates(entries)
    }

    // MARK: - Top Artists

    func getTopArtists(user: String, period: String = "overall", limit: Int = 50) async throws -> [TopArtistEntry] {
        let url = try requestURL(["method": "user.getTopArtists", "user": user, "period": period, "limit": String(limit)])
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

    // MARK: - Top Tracks

    func getTopTracks(user: String, period: String = "overall", limit: Int = 50) async throws -> [TopTrackEntry] {
        let url = try requestURL(["method": "user.getTopTracks", "user": user, "period": period, "limit": String(limit)])
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let topTracks = json?["toptracks"] as? [String: Any],
              let tracks = topTracks["track"] as? [[String: Any]] else {
            return []
        }

        return tracks.compactMap { dict -> TopTrackEntry? in
            guard let name = dict["name"] as? String else { return nil }
            let artist = (dict["artist"] as? [String: Any])?["name"] as? String ?? ""
            let playcount = Int((dict["playcount"] as? String) ?? "0") ?? 0
            let imageURL = extractImageURL(from: dict)
            let url = URL(string: (dict["url"] as? String) ?? "")
            return TopTrackEntry(name: name, artistName: artist, playcount: playcount, imageURL: imageURL, lastfmURL: url)
        }
    }

    // MARK: - Auth

    func getAuthToken() async throws -> String {
        let url = try requestURL(["method": "auth.getToken"])
        let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["token"] as? String else { throw LastFMError.authFailed }
        return token
    }

    func getSession(token: String) async throws -> (sessionKey: String, username: String) {
        let params = ["api_key": apiKey, "method": "auth.getSession", "token": token]
        var query = params
        query["api_sig"] = Self.signature(params: params, secret: sharedSecret)
        let url = try requestURL(query)
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
        "https://www.last.fm/api/auth/?api_key=\(apiKey.queryValueEncoded)"
    }

    // MARK: - Scrobble / Now Playing

    func updateNowPlaying(artist: String, track: String, album: String) async throws {
        guard let sk = sessionKey() else { throw LastFMError.notAuthenticated }
        let params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": artist, "track": track, "album": album,
            "api_key": apiKey, "sk": sk
        ]
        try await signedPost(params: params)
    }

    func scrobble(artist: String, track: String, album: String, timestamp: Int) async throws {
        guard let sk = sessionKey() else { throw LastFMError.notAuthenticated }
        let params: [String: String] = [
            "method": "track.scrobble",
            "artist": artist, "track": track, "album": album,
            "timestamp": String(timestamp),
            "api_key": apiKey, "sk": sk
        ]
        let data = try await signedPost(params: params)
        try Self.checkScrobbleAccepted(data)
    }

    // MARK: - Love / Unlove

    func loveTrack(artist: String, track: String) async throws {
        try await setLoved(true, artist: artist, track: track)
    }

    func unloveTrack(artist: String, track: String) async throws {
        try await setLoved(false, artist: artist, track: track)
    }

    private func setLoved(_ loved: Bool, artist: String, track: String) async throws {
        guard let session = sessionKey() else { throw LastFMError.notAuthenticated }
        try await signedPost(params: [
            "method": loved ? "track.love" : "track.unlove",
            "artist": artist, "track": track,
            "api_key": apiKey, "sk": session
        ])
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

    private func requestURL(_ params: [String: String]) throws -> URL {
        var query = params
        query["api_key"] = query["api_key"] ?? apiKey
        query["format"] = "json"
        guard let url = URL(string: baseURL + "?" + Self.formBody(query)) else { throw LastFMError.requestFailed }
        return url
    }

    @discardableResult
    private func signedPost(params: [String: String]) async throws -> Data {
        var allParams = params
        allParams["api_sig"] = Self.signature(params: params, secret: sharedSecret)
        allParams["format"] = "json"

        guard let url = URL(string: baseURL) else { throw LastFMError.requestFailed }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.formBody(allParams).utf8)

        let (data, response) = try await URLSession.shared.trackedData(for: request, service: "Last.fm")
        do {
            try Self.checkResponse(data: data, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch LastFMError.api(9, _) {
            invalidateSession()
            throw LastFMError.api(code: 9, message: "Invalid session key")
        }
        return data
    }

    enum LastFMError: LocalizedError, Equatable {
        case authFailed
        case requestFailed
        case notAuthenticated
        case api(code: Int, message: String)
        case ignored(code: Int)

        enum Disposition { case retry, keepUntilFixed, drop }

        /// A wrong retry costs a request; a wrong drop loses the scrobble for good. So drop only what is certainly
        /// permanent and about this scrobble (https://www.last.fm/api/errorcodes, track.scrobble ignored codes);
        /// credential faults (4, 9, 10, 13, 26) stop the pass and keep the queue.
        var disposition: Disposition {
            switch self {
            case .requestFailed, .authFailed: return .retry
            case .api(let code, _) where [8, 11, 16, 29].contains(code): return .retry
            case .ignored(5): return .retry
            case .notAuthenticated: return .keepUntilFixed
            case .api(let code, _) where [4, 9, 10, 13, 26].contains(code): return .keepUntilFixed
            case .api, .ignored: return .drop
            }
        }

        var errorDescription: String? {
            switch self {
            case .authFailed: return "Last.fm authentication failed"
            case .requestFailed: return "Last.fm request failed"
            case .notAuthenticated: return "Not signed in to Last.fm"
            case let .api(code, message): return "Last.fm error \(code): \(message)"
            case .ignored(let code): return "Last.fm ignored the scrobble (code \(code))"
            }
        }
    }
}

extension LastFMService {
    static func recentTracksParams(user: String, limit: Int, from start: Date?, to end: Date?) -> [String: String] {
        var params = ["method": "user.getRecentTracks", "user": user, "limit": String(limit), "extended": "1"]
        if let start { params["from"] = String(Int(start.timeIntervalSince1970)) }
        if let end { params["to"] = String(Int(end.timeIntervalSince1970)) }
        return params
    }

    /// Last.fm reports API errors in the body, sometimes with HTTP 200, so the body is checked before the status.
    static func checkResponse(data: Data, statusCode: Int) throws {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        if let code = json?["error"] as? Int {
            throw LastFMError.api(code: code, message: json?["message"] as? String ?? "")
        }
        guard statusCode == 200 else { throw LastFMError.requestFailed }
    }

    static func checkScrobbleAccepted(_ data: Data) throws {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let scrobbles = json["scrobbles"] as? [String: Any],
              let attr = scrobbles["@attr"] as? [String: Any] else { return }
        guard intValue(attr["ignored"]) > 0 else { return }
        let scrobble = (scrobbles["scrobble"] as? [String: Any]) ?? (scrobbles["scrobble"] as? [[String: Any]])?.first
        let ignoredMessage = scrobble?["ignoredMessage"] as? [String: Any]
        throw LastFMError.ignored(code: intValue(ignoredMessage?["code"]))
    }

    private static func intValue(_ value: Any?) -> Int {
        if let int = value as? Int { return int }
        return Int(value as? String ?? "") ?? 0
    }

    static func formBody(_ params: [String: String]) -> String {
        params.sorted { $0.key < $1.key }
            .map { "\($0.key.queryValueEncoded)=\($0.value.queryValueEncoded)" }
            .joined(separator: "&")
    }

    /// Signed over the raw, unencoded values, as https://www.last.fm/api/authspec specifies.
    static func signature(params: [String: String], secret: String) -> String {
        let sigString = params.sorted { $0.key < $1.key }.map { "\($0.key)\($0.value)" }.joined() + secret
        let digest = Insecure.MD5.hash(data: Data(sigString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
