import Foundation

struct ScrobbleRules {
    var thresholdPercent: Double
    var minTrackDuration: TimeInterval

    func threshold(for track: SystemNowPlaying) -> TimeInterval {
        if track.duration > 0 {
            return max(minTrackDuration, min(track.duration * thresholdPercent / 100, 240))
        }
        return max(minTrackDuration, 60)
    }
}

struct PendingScrobble: Equatable {
    let track: SystemNowPlaying
    let timestamp: Int
}

struct ScrobbleEngine {
    private(set) var current: SystemNowPlaying?
    private(set) var accumulatedPlayTime: TimeInterval = 0
    private(set) var didScrobbleCurrent = false
    private var lastTick: Date?
    private var lastScrobbledKey = ""

    func progress(rules: ScrobbleRules) -> Double {
        guard let current else { return 0 }
        let threshold = rules.threshold(for: current)
        return threshold > 0 ? min(1, accumulatedPlayTime / threshold) : 0
    }

    mutating func trackChanged(
        to newTrack: SystemNowPlaying?, now: Date, rules: ScrobbleRules, isAllowed: (SystemNowPlaying) -> Bool
    ) -> [PendingScrobble] {
        var scrobbles: [PendingScrobble] = []
        if let old = current, !didScrobbleCurrent, accumulatedPlayTime >= 30 {
            scrobbles += submit(old, now: now, rules: rules, isAllowed: isAllowed)
        }

        current = newTrack
        didScrobbleCurrent = false
        lastTick = now
        accumulatedPlayTime = max(0, newTrack?.elapsed ?? 0)

        if let track = newTrack, accumulatedPlayTime >= rules.threshold(for: track) {
            scrobbles += submit(track, now: now, rules: rules, isAllowed: isAllowed)
        }
        return scrobbles
    }

    mutating func tick(
        isPlaying: Bool, now: Date, rules: ScrobbleRules, isAllowed: (SystemNowPlaying) -> Bool
    ) -> [PendingScrobble] {
        guard let track = current, isPlaying, !didScrobbleCurrent else {
            lastTick = now
            return []
        }
        if let lastTick {
            let delta = now.timeIntervalSince(lastTick)
            // Big gaps are sleep or a stalled timer, not listening.
            if delta < 3 { accumulatedPlayTime += delta }
        }
        lastTick = now

        guard accumulatedPlayTime >= rules.threshold(for: track) else { return [] }
        return submit(track, now: now, rules: rules, isAllowed: isAllowed)
    }

    private mutating func submit(
        _ track: SystemNowPlaying, now: Date, rules: ScrobbleRules, isAllowed: (SystemNowPlaying) -> Bool
    ) -> [PendingScrobble] {
        guard isAllowed(track) else { return [] }
        if track.duration > 0 && track.duration < rules.minTrackDuration { return [] }
        let key = "\(track.artist)|\(track.title)"
        guard key != lastScrobbledKey else { return [] }
        lastScrobbledKey = key
        didScrobbleCurrent = true
        return [PendingScrobble(track: track, timestamp: Int(now.timeIntervalSince1970))]
    }
}
