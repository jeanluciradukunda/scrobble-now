import Foundation

struct ScrobbleRules {
    var thresholdPercent: Double
    var minTrackDuration: TimeInterval

    /// Last.fm's floors: a track must be longer than 30 s and played for half its length (or 4 minutes).
    var clamped: ScrobbleRules {
        ScrobbleRules(thresholdPercent: max(50, thresholdPercent), minTrackDuration: max(30, minTrackDuration))
    }

    func threshold(for track: SystemNowPlaying) -> TimeInterval {
        let rules = clamped
        if track.duration > 0 {
            return max(rules.minTrackDuration, min(track.duration * rules.thresholdPercent / 100, 240))
        }
        return max(rules.minTrackDuration, 60)
    }

    func isLongEnough(_ track: SystemNowPlaying) -> Bool {
        track.duration <= 0 || track.duration > clamped.minTrackDuration
    }
}

struct PendingScrobble: Equatable {
    let track: SystemNowPlaying
    let timestamp: Int
}

struct ScrobbleRecord: Codable, Equatable {
    let artist: String
    let title: String
    let timestamp: Int
}

struct ScrobbleEngine {
    private struct Play {
        let track: SystemNowPlaying
        var startedAt: Date
        var accumulated: TimeInterval
        var didScrobble: Bool
        var lastHeard: Date
    }

    /// A paused source can disappear and come back as a "new" track; within this window it is the same play.
    static let resumeWindow: TimeInterval = 600

    private var play: Play?
    private var previous: Play?
    private var lastTick: Date?
    private(set) var lastScrobbled: ScrobbleRecord?

    init(lastScrobbled: ScrobbleRecord? = nil) {
        self.lastScrobbled = lastScrobbled
    }

    var current: SystemNowPlaying? { play?.track }
    var accumulatedPlayTime: TimeInterval { play?.accumulated ?? 0 }
    var didScrobbleCurrent: Bool { play?.didScrobble ?? false }

    func progress(rules: ScrobbleRules) -> Double {
        guard let play else { return 0 }
        if play.didScrobble { return 1 }
        let threshold = rules.threshold(for: play.track)
        return threshold > 0 ? min(1, play.accumulated / threshold) : 0
    }

    mutating func trackChanged(
        to newTrack: SystemNowPlaying?, now: Date, rules: ScrobbleRules, isAllowed: (SystemNowPlaying) -> Bool
    ) -> [PendingScrobble] {
        lastTick = now
        if let play { previous = play }
        guard let newTrack else {
            play = nil
            return []
        }
        if let resumed = resumedPlay(of: newTrack, now: now) {
            play = resumed
            return []
        }
        let elapsed = max(0, newTrack.elapsed)
        play = Play(track: newTrack, startedAt: now.addingTimeInterval(-elapsed), accumulated: elapsed,
                    didScrobble: false, lastHeard: now)
        return scrobbleIfDue(now: now, rules: rules, isAllowed: isAllowed)
    }

    mutating func tick(
        isPlaying: Bool, canRepeat: Bool = true, now: Date, rules: ScrobbleRules,
        isAllowed: (SystemNowPlaying) -> Bool
    ) -> [PendingScrobble] {
        defer { lastTick = now }
        guard isPlaying, var current = play else { return [] }
        if let lastTick {
            let delta = now.timeIntervalSince(lastTick)
            // Big gaps are sleep or a stalled timer, not listening.
            if delta < 3 { current.accumulated += delta }
        }
        current.lastHeard = now

        // Playing on past the end of the track means it started again (repeat or loop).
        let duration = current.track.duration
        if canRepeat, duration > 0, current.accumulated >= duration + 2 {
            let intoRepeat = current.accumulated - duration
            current = Play(track: current.track, startedAt: now.addingTimeInterval(-intoRepeat),
                           accumulated: intoRepeat, didScrobble: false, lastHeard: now)
        }
        play = current
        return scrobbleIfDue(now: now, rules: rules, isAllowed: isAllowed)
    }

    private func resumedPlay(of track: SystemNowPlaying, now: Date) -> Play? {
        guard var earlier = previous, earlier.track == track,
              track.elapsed <= 0 || track.elapsed >= earlier.accumulated - 5 else { return nil }
        // A scrobbled track that never reached its end is still the same listen, however long the pause.
        let unfinished = earlier.didScrobble && earlier.track.duration > 0 && earlier.accumulated < earlier.track.duration
        guard unfinished || now.timeIntervalSince(earlier.lastHeard) < Self.resumeWindow else { return nil }
        if track.elapsed > 0 { earlier.accumulated = track.elapsed }
        earlier.lastHeard = now
        return earlier
    }

    private mutating func scrobbleIfDue(
        now: Date, rules: ScrobbleRules, isAllowed: (SystemNowPlaying) -> Bool
    ) -> [PendingScrobble] {
        guard var current = play, !current.didScrobble,
              current.accumulated >= rules.threshold(for: current.track),
              rules.isLongEnough(current.track),
              isAllowed(current.track) else { return [] }
        current.didScrobble = true
        play = current

        let record = ScrobbleRecord(artist: current.track.artist, title: current.track.title,
                                    timestamp: Int(current.startedAt.timeIntervalSince1970))
        if let last = lastScrobbled, last.artist == record.artist, last.title == record.title,
           abs(last.timestamp - record.timestamp) < 60 {
            return []
        }
        lastScrobbled = record
        return [PendingScrobble(track: current.track, timestamp: record.timestamp)]
    }
}
