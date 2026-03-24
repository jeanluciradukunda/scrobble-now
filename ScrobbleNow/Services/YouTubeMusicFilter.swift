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
                let artist = videoDetails["author"] as? String
                let track = videoDetails["title"] as? String

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
