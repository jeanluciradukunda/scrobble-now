import Foundation

/// Determines if a YouTube video is music and extracts proper track info.
/// Uses two methods:
/// 1. YouTube page category check ("category":"Music")
/// 2. YouTube Music API recognition (musicVideoType)
actor YouTubeMusicFilter {
    static let shared = YouTubeMusicFilter()

    struct MusicCheckResult {
        let isMusic: Bool
        let artist: String?
        let track: String?
        let album: String?
        let durationSeconds: Double?
    }

    // Cache results to avoid repeated API calls
    private var cache: [String: MusicCheckResult] = [:]

    /// Check if a YouTube video ID is music. Returns nil if unknown (still checking).
    func check(videoId: String) async -> MusicCheckResult {
        // Return cached result
        if let cached = cache[videoId] {
            return cached
        }

        // Try YouTube Music API first (more reliable, also gives artist/track)
        if let ytMusicResult = await checkYouTubeMusic(videoId: videoId) {
            cache[videoId] = ytMusicResult
            return ytMusicResult
        }

        // Fallback: check page category
        let categoryResult = await checkCategory(videoId: videoId)
        cache[videoId] = categoryResult
        return categoryResult
    }

    /// Determine if it's "Artist - Track" or "Track - Artist" by checking Last.fm
    /// If left side is a known artist → Artist - Track
    /// If right side is a known artist → Track - Artist (swap)
    /// If neither or both → default to left = Artist
    static func validateArtistTrackOrder(left: String, right: String, apiKey: String) async -> (artist: String, track: String) {
        guard !apiKey.isEmpty else { return (left, right) }

        // Check if left is a known artist on Last.fm
        let leftIsArtist = await checkArtistExists(name: left, apiKey: apiKey)
        let rightIsArtist = await checkArtistExists(name: right, apiKey: apiKey)

        if leftIsArtist && !rightIsArtist {
            return (left, right) // Artist - Track (normal)
        } else if rightIsArtist && !leftIsArtist {
            return (right, left) // Track - Artist (swapped)
        }
        // Both or neither — default to left = artist
        return (left, right)
    }

    private static func checkArtistExists(name: String, apiKey: String) async -> Bool {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://ws.audioscrobbler.com/2.0/?method=artist.getInfo&artist=\(encoded)&api_key=\(apiKey)&format=json") else { return false }

        do {
            let (data, _) = try await URLSession.shared.trackedData(from: url, service: "Last.fm")
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let artist = json["artist"] as? [String: Any],
               let listeners = artist["stats"] as? [String: Any],
               let count = listeners["listeners"] as? String,
               let num = Int(count), num > 100 {
                return true // Artist exists and has >100 listeners
            }
        } catch {}
        return false
    }

    /// Parse "Artist - Track (ft. Guest)" style video titles
    static func parseVideoTitle(_ title: String) -> (artist: String, track: String) {
        var cleaned = title

        // Remove common suffixes
        for suffix in [" (Official Video)", " (Official Audio)", " (Official Music Video)",
                       " (Lyric Video)", " (Lyrics)", " [Official Video]", " [Official Audio]",
                       " (Audio)", " (Visualizer)", " | Official Video", " (MV)", " [MV]",
                       " (Official Visualizer)"] {
            cleaned = cleaned.replacingOccurrences(of: suffix, with: "", options: .caseInsensitive)
        }

        // Try splitting on " - " (most common: "Artist - Track")
        let dashParts = cleaned.components(separatedBy: " - ")
        if dashParts.count >= 2 {
            let artist = dashParts[0].trimmingCharacters(in: .whitespaces)
            // Rejoin remaining parts as track (handles "Artist - Track - Remix")
            let track = dashParts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            return (artist, track)
        }

        // Try splitting on " – " (en dash)
        let enDashParts = cleaned.components(separatedBy: " – ")
        if enDashParts.count >= 2 {
            return (enDashParts[0].trimmingCharacters(in: .whitespaces),
                    enDashParts.dropFirst().joined(separator: " – ").trimmingCharacters(in: .whitespaces))
        }

        // Try splitting on " — " (em dash)
        let emDashParts = cleaned.components(separatedBy: " — ")
        if emDashParts.count >= 2 {
            return (emDashParts[0].trimmingCharacters(in: .whitespaces),
                    emDashParts.dropFirst().joined(separator: " — ").trimmingCharacters(in: .whitespaces))
        }

        // Try "Track" by Artist pattern
        if let byRange = cleaned.range(of: " by ", options: .caseInsensitive) {
            let track = String(cleaned[cleaned.startIndex..<byRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let artist = String(cleaned[byRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !artist.isEmpty && !track.isEmpty {
                return (artist, track)
            }
        }

        // No separator found
        return ("", cleaned)
    }

    /// Extract video ID from a YouTube URL
    static func extractVideoId(from url: String) -> String? {
        // youtube.com/watch?v=XXX
        if let range = url.range(of: "v=") {
            let start = range.upperBound
            let rest = url[start...]
            let end = rest.firstIndex(where: { $0 == "&" || $0 == "#" }) ?? rest.endIndex
            let videoId = String(rest[..<end])
            return videoId.isEmpty ? nil : videoId
        }
        // youtu.be/XXX
        if url.contains("youtu.be/") {
            let parts = url.components(separatedBy: "youtu.be/")
            if let last = parts.last {
                let id = last.components(separatedBy: "?").first ?? last
                return id.isEmpty ? nil : id
            }
        }
        return nil
    }

    // MARK: - YouTube Music API Check

    private func checkYouTubeMusic(videoId: String) async -> MusicCheckResult? {
        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20221212.01.00",
                ]
            ],
            "captionParams": [:],
            "videoId": videoId,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: URL(string: "https://music.youtube.com/youtubei/v1/player")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 5

        do {
            let (data, _) = try await URLSession.shared.trackedData(for: request, service: "YouTube Music")
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let videoDetails = json["videoDetails"] as? [String: Any] else { return nil }

            let musicVideoType = videoDetails["musicVideoType"] as? String ?? ""
            let isMusic = musicVideoType.hasPrefix("MUSIC_VIDEO_")

            let duration = (videoDetails["lengthSeconds"] as? String).flatMap { Double($0) }

            if isMusic {
                let author = videoDetails["author"] as? String ?? ""
                let title = videoDetails["title"] as? String ?? ""

                var artist: String
                var track: String

                // For OMV (Official Music Video) and ATV (Art Track Video),
                // author is the real artist and title is the track name
                if musicVideoType == "MUSIC_VIDEO_TYPE_OMV" || musicVideoType == "MUSIC_VIDEO_TYPE_ATV" {
                    artist = author
                    track = title
                } else {
                    // For UGC (User Generated Content), the author is usually the channel name
                    // (e.g., "posh isolation sounds"), not the artist.
                    // The title often contains "Artist - Track" or "Track - Artist"
                    let parsed = Self.parseVideoTitle(title)

                    if parsed.artist.isEmpty {
                        // No separator found — fall back to author
                        artist = author
                        track = title
                    } else {
                        // We have a split — but is it "Artist - Track" or "Track - Artist"?
                        // Validate with Last.fm: the real artist should have a Last.fm page
                        let (validatedArtist, validatedTrack) = await Self.validateArtistTrackOrder(
                            left: parsed.artist, right: parsed.track, apiKey: KeychainService.lastfmApiKey
                        )
                        artist = validatedArtist
                        track = validatedTrack
                    }
                }

                return MusicCheckResult(
                    isMusic: true,
                    artist: artist,
                    track: track,
                    album: nil,
                    durationSeconds: duration
                )
            }

            return MusicCheckResult(isMusic: false, artist: nil, track: nil, album: nil, durationSeconds: nil)
        } catch {
            return nil
        }
    }

    // MARK: - YouTube Page Category Check

    private func checkCategory(videoId: String) async -> MusicCheckResult {
        let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (data, _) = try await URLSession.shared.trackedData(for: request, service: "YouTube Music")
            guard let html = String(data: data, encoding: .utf8) else {
                return MusicCheckResult(isMusic: false, artist: nil, track: nil, album: nil, durationSeconds: nil)
            }

            // Look for "category":"Music" in the page source
            if let range = html.range(of: #""category":"([^"]+)""#, options: .regularExpression) {
                let category = html[range]
                    .replacingOccurrences(of: "\"category\":\"", with: "")
                    .replacingOccurrences(of: "\"", with: "")

                let isMusic = category == "Music" || category == "Entertainment"
                return MusicCheckResult(isMusic: isMusic, artist: nil, track: nil, album: nil, durationSeconds: nil)
            }
        } catch {
            // Network error — be permissive, allow scrobble
        }

        return MusicCheckResult(isMusic: false, artist: nil, track: nil, album: nil, durationSeconds: nil)
    }

    /// Clear old cache entries (call periodically)
    func cleanCache() {
        if cache.count > 200 {
            // Remove oldest half
            let keys = Array(cache.keys.prefix(100))
            for key in keys { cache.removeValue(forKey: key) }
        }
    }
}
