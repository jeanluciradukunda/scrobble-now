import Foundation
import Testing
@testable import Scrobble_Now

private let rules = ScrobbleRules(thresholdPercent: 50, minTrackDuration: 30)
private let allowAll: (SystemNowPlaying) -> Bool = { _ in true }
private let start = Date(timeIntervalSince1970: 1_000_000)

private func track(_ title: String, duration: Double = 200, elapsed: Double = 0) -> SystemNowPlaying {
    SystemNowPlaying(title: title, artist: "Artist", album: "Album", duration: duration, elapsed: elapsed,
                     playbackRate: 1, artwork: nil, sourceBundleId: "com.spotify.client",
                     sourceAppName: "Spotify", timestamp: start)
}

/// Plays for `seconds` in one-second ticks starting at `from`, returning every scrobble and the end time.
private func play(_ engine: inout ScrobbleEngine, seconds: Int, from: Date) -> ([PendingScrobble], Date) {
    var scrobbles: [PendingScrobble] = []
    var now = from
    for _ in 0..<seconds {
        now = now.addingTimeInterval(1)
        scrobbles += engine.tick(isPlaying: true, now: now, rules: rules, isAllowed: allowAll)
    }
    return (scrobbles, now)
}

struct ScrobbleRulesTests {
    @Test func thresholdFollowsLastFMRules() {
        #expect(rules.threshold(for: track("a", duration: 200)) == 100)
        #expect(rules.threshold(for: track("a", duration: 600)) == 240)
        #expect(rules.threshold(for: track("a", duration: 40)) == 30)
        #expect(rules.threshold(for: track("a", duration: 0)) == 60)
    }
}

struct ScrobbleEngineTests {
    @Test func scrobblesOnceWhenThresholdIsReached() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (early, mid) = play(&engine, seconds: 99, from: start)
        #expect(early.isEmpty)
        let (atThreshold, _) = play(&engine, seconds: 50, from: mid)
        #expect(atThreshold.count == 1)
        #expect(engine.didScrobbleCurrent)
    }

    @Test func gapsOfThreeSecondsOrMoreAreNotCounted() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        _ = engine.tick(isPlaying: true, now: start.addingTimeInterval(10), rules: rules, isAllowed: allowAll)
        #expect(engine.accumulatedPlayTime == 0)
    }

    @Test func pausedTimeIsNotCounted() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        _ = engine.tick(isPlaying: false, now: start.addingTimeInterval(1), rules: rules, isAllowed: allowAll)
        _ = engine.tick(isPlaying: false, now: start.addingTimeInterval(2), rules: rules, isAllowed: allowAll)
        #expect(engine.accumulatedPlayTime == 0)
    }

    @Test func notScrobbledWhenDisallowedOrTooShort() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules) { _ in false }
        var now = start
        var scrobbles: [PendingScrobble] = []
        for _ in 0..<150 {
            now = now.addingTimeInterval(1)
            scrobbles += engine.tick(isPlaying: true, now: now, rules: rules) { _ in false }
        }
        #expect(scrobbles.isEmpty)

        var shortTrack = ScrobbleEngine()
        _ = shortTrack.trackChanged(to: track("jingle", duration: 20), now: start, rules: rules, isAllowed: allowAll)
        #expect(play(&shortTrack, seconds: 60, from: start).0.isEmpty)
    }

    // Characterisation of current behaviour that the swiss found wrong (A5 to A8); 1g changes each of these.

    @Test func currentBehaviourTimestampIsSubmitTime() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (scrobbles, _) = play(&engine, seconds: 100, from: start)
        #expect(scrobbles.first?.timestamp == Int(start.timeIntervalSince1970) + 100)
    }

    @Test func currentBehaviourForceScrobblesOnChangeAfter30Seconds() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("long", duration: 600), now: start, rules: rules, isAllowed: allowAll)
        let (_, now) = play(&engine, seconds: 31, from: start)
        let scrobbles = engine.trackChanged(to: track("next"), now: now, rules: rules, isAllowed: allowAll)
        #expect(scrobbles.map(\.track.title) == ["long"])
    }

    @Test func currentBehaviourRepeatPlaysAreSuppressed() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (first, now) = play(&engine, seconds: 100, from: start)
        _ = engine.trackChanged(to: track("a"), now: now, rules: rules, isAllowed: allowAll)
        let (second, _) = play(&engine, seconds: 100, from: now)
        #expect(first.count == 1)
        #expect(second.isEmpty)
    }

    @Test func currentBehaviourElapsedPastThresholdScrobblesImmediately() {
        var engine = ScrobbleEngine()
        let scrobbles = engine.trackChanged(to: track("a", elapsed: 150), now: start, rules: rules, isAllowed: allowAll)
        #expect(scrobbles.count == 1)
    }
}
