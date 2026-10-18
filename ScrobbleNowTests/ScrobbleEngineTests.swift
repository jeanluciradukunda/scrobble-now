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

    @Test func timestampIsWhenThePlayStarted() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (scrobbles, _) = play(&engine, seconds: 100, from: start)
        #expect(scrobbles.first?.timestamp == Int(start.timeIntervalSince1970))
    }

    @Test func skippingBeforeTheThresholdDoesNotScrobble() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("long", duration: 600), now: start, rules: rules, isAllowed: allowAll)
        let (_, now) = play(&engine, seconds: 40, from: start)
        #expect(engine.trackChanged(to: track("next"), now: now, rules: rules, isAllowed: allowAll).isEmpty)
    }

    @Test func aRepeatedTrackScrobblesEachTime() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("loop", duration: 120), now: start, rules: rules, isAllowed: allowAll)
        let (scrobbles, _) = play(&engine, seconds: 250, from: start)
        #expect(scrobbles.count == 2)
        #expect(scrobbles[1].timestamp - scrobbles[0].timestamp >= 120)
    }

    @Test func aThenBThenAScrobblesThreeTimes() {
        var engine = ScrobbleEngine()
        var now = start
        var scrobbles: [PendingScrobble] = []
        for title in ["a", "b", "a"] {
            scrobbles += engine.trackChanged(to: track(title), now: now, rules: rules, isAllowed: allowAll)
            let result = play(&engine, seconds: 110, from: now)
            scrobbles += result.0
            now = result.1
        }
        #expect(scrobbles.map(\.track.title) == ["a", "b", "a"])
    }

    @Test func pauseAndResumeOfTheSameTrackIsOnePlay() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (first, mid) = play(&engine, seconds: 120, from: start)
        // The paused source is evicted, then comes back with no elapsed time (Spotify, Music).
        _ = engine.trackChanged(to: nil, now: mid.addingTimeInterval(60), rules: rules, isAllowed: allowAll)
        let resumedAt = mid.addingTimeInterval(120)
        let onResume = engine.trackChanged(to: track("a"), now: resumedAt, rules: rules, isAllowed: allowAll)
        let (afterResume, _) = play(&engine, seconds: 60, from: resumedAt)
        #expect(first.count == 1)
        #expect(onResume.isEmpty)
        #expect(afterResume.isEmpty)
        #expect(engine.didScrobbleCurrent)
        #expect(engine.accumulatedPlayTime == 180)
    }

    @Test func resumingWithAReportedPositionKeepsThatPosition() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (_, mid) = play(&engine, seconds: 50, from: start)
        _ = engine.trackChanged(to: nil, now: mid, rules: rules, isAllowed: allowAll)
        _ = engine.trackChanged(to: track("a", elapsed: 52), now: mid.addingTimeInterval(30), rules: rules, isAllowed: allowAll)
        #expect(engine.accumulatedPlayTime == 52)
    }

    @Test func goingBackToTheStartIsANewPlay() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (_, mid) = play(&engine, seconds: 120, from: start)
        _ = engine.trackChanged(to: nil, now: mid, rules: rules, isAllowed: allowAll)
        _ = engine.trackChanged(to: track("a", elapsed: 3), now: mid.addingTimeInterval(10), rules: rules, isAllowed: allowAll)
        #expect(!engine.didScrobbleCurrent)
        #expect(engine.accumulatedPlayTime == 3)
    }

    @Test func aLongTrackPausedForAgesStillScrobblesOnce() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("mix", duration: 1200), now: start, rules: rules, isAllowed: allowAll)
        let (first, mid) = play(&engine, seconds: 300, from: start)
        _ = engine.trackChanged(to: nil, now: mid, rules: rules, isAllowed: allowAll)
        let resumedAt = mid.addingTimeInterval(3600)
        _ = engine.trackChanged(to: track("mix", duration: 1200), now: resumedAt, rules: rules, isAllowed: allowAll)
        let (afterResume, _) = play(&engine, seconds: 600, from: resumedAt)
        #expect(first.count == 1)
        #expect(afterResume.isEmpty)
    }

    @Test func noRepeatsWhenRepeatDetectionIsOff() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("tab", duration: 120), now: start, rules: rules, isAllowed: allowAll)
        var now = start
        var scrobbles: [PendingScrobble] = []
        for _ in 0..<3600 {
            now = now.addingTimeInterval(1)
            scrobbles += engine.tick(isPlaying: true, canRepeat: false, now: now, rules: rules, isAllowed: allowAll)
        }
        #expect(scrobbles.count == 1)
    }

    @Test func pausedSourceAccruesNothingAfterTheScrobble() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (first, mid) = play(&engine, seconds: 110, from: start)
        var now = mid
        var later: [PendingScrobble] = []
        for _ in 0..<3600 {
            now = now.addingTimeInterval(1)
            later += engine.tick(isPlaying: false, now: now, rules: rules, isAllowed: allowAll)
        }
        #expect(first.count == 1)
        #expect(later.isEmpty)
    }

    @Test func restartingMidTrackDoesNotScrobbleAgain() {
        var before = ScrobbleEngine()
        _ = before.trackChanged(to: track("a"), now: start, rules: rules, isAllowed: allowAll)
        let (sent, now) = play(&before, seconds: 150, from: start)
        #expect(sent.count == 1)

        var afterRestart = ScrobbleEngine(lastScrobbled: before.lastScrobbled)
        let seeded = afterRestart.trackChanged(to: track("a", elapsed: 151), now: now.addingTimeInterval(2),
                                               rules: rules, isAllowed: allowAll)
        #expect(seeded.isEmpty)
        #expect(afterRestart.didScrobbleCurrent)
    }

    @Test func aThirtySecondTrackIsTooShort() {
        var engine = ScrobbleEngine()
        _ = engine.trackChanged(to: track("jingle", duration: 30), now: start, rules: rules, isAllowed: allowAll)
        #expect(play(&engine, seconds: 60, from: start).0.isEmpty)
    }

    @Test func settingsBelowLastFMFloorsAreClamped() {
        let lax = ScrobbleRules(thresholdPercent: 25, minTrackDuration: 10)
        #expect(lax.threshold(for: track("a", duration: 200)) == 100)
        #expect(!lax.isLongEnough(track("a", duration: 20)))
    }
}

struct ScrobblePlayStateTests {
    private func source(rate: Double) -> SystemNowPlaying {
        SystemNowPlaying(title: "a", artist: "b", album: "", duration: 200, elapsed: 0, playbackRate: rate,
                         artwork: nil, sourceBundleId: "com.spotify.client", sourceAppName: "Spotify", timestamp: start)
    }

    @Test func pausedSourceDoesNotCountWhileAnotherSourcePlays() {
        #expect(!SystemScrobbleService.countsPlayTime(bridgeIsPlaying: true, source: source(rate: 0)))
        #expect(!SystemScrobbleService.countsPlayTime(bridgeIsPlaying: true, source: nil))
        #expect(SystemScrobbleService.countsPlayTime(bridgeIsPlaying: true, source: source(rate: 1)))
        #expect(!SystemScrobbleService.countsPlayTime(bridgeIsPlaying: false, source: source(rate: 1)))
    }

    @Test func browserTabsNeverRepeat() {
        #expect(!SystemScrobbleService.canDetectRepeats(bundleId: "com.google.Chrome"))
        #expect(!SystemScrobbleService.canDetectRepeats(bundleId: "com.apple.Safari"))
        #expect(SystemScrobbleService.canDetectRepeats(bundleId: "com.spotify.client"))
    }
}

struct BrowserSourceTests {
    @Test func browsersAreRecognised() {
        #expect(SystemScrobbleService.isBrowser("com.google.Chrome"))
        #expect(SystemScrobbleService.isBrowser("com.apple.Safari"))
        #expect(!SystemScrobbleService.isBrowser("com.spotify.client"))
    }
}
