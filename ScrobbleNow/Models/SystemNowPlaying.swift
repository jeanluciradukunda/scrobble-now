import Foundation

struct SystemNowPlaying: Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let elapsed: Double
    let playbackRate: Double
    let artwork: PlatformImage?
    let sourceBundleId: String
    let sourceAppName: String
    let timestamp: Date

    var isPlaying: Bool { playbackRate > 0 }
    var progress: Double { duration > 0 ? min(1, elapsed / duration) : 0 }
    var elapsedFormatted: String { formatTime(elapsed) }
    var durationFormatted: String { formatTime(duration) }
    var remainingFormatted: String { formatTime(max(0, duration - elapsed)) }

    func withArtwork(_ img: PlatformImage) -> SystemNowPlaying {
        SystemNowPlaying(title: title, artist: artist, album: album,
                         duration: duration, elapsed: elapsed, playbackRate: playbackRate,
                         artwork: img, sourceBundleId: sourceBundleId,
                         sourceAppName: sourceAppName, timestamp: timestamp)
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60; let s = Int(seconds) % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    static func == (lhs: SystemNowPlaying, rhs: SystemNowPlaying) -> Bool {
        lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.sourceBundleId == rhs.sourceBundleId
    }
}
