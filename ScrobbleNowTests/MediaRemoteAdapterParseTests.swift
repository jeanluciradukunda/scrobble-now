import Foundation
import Testing
@testable import Scrobble_Now

struct MediaRemoteAdapterParseTests {
    private let now = ISO8601DateFormatter().date(from: "2026-10-18T13:58:20Z")!

    private func parse(_ line: String) -> AdapterUpdate? {
        MediaRemoteAdapterSource.parse(line: line, now: now) { "App(\($0))" }
    }

    private func track(_ line: String) -> SystemNowPlaying? {
        if case .track(let track) = parse(line) { return track }
        return nil
    }

    @Test func emptyPayloadMeansNothingPlaying() {
        #expect(parse(#"{"type":"data","diff":false,"payload":{}}"#) == .nothingPlaying)
    }

    @Test func unrelatedLinesAreIgnored() {
        #expect(parse("not json") == nil)
        #expect(parse(#"{"type":"other","payload":{}}"#) == nil)
    }

    @Test func playingMusicTrackExtrapolatesElapsedFromTimestamp() throws {
        let line = #"{"type":"data","diff":false,"payload":{"playbackRate":1,"artist":"Malibu","#
            + #""album":"Palaces of Pity (Special Edition)","elapsedTime":0.977,"timestamp":"2026-10-18T13:58:10Z","#
            + #""contentItemIdentifier":"219186::219198","bundleIdentifier":"com.apple.Music","playing":true,"#
            + #""title":"Iliad II (Light Over Me)","duration":131.5}}"#
        let parsed = try #require(track(line))
        #expect(parsed.title == "Iliad II (Light Over Me)")
        #expect(parsed.artist == "Malibu")
        #expect(parsed.sourceBundleId == "com.apple.Music")
        #expect(parsed.sourceAppName == "App(com.apple.Music)")
        #expect(parsed.isPlaying)
        #expect(abs(parsed.elapsed - 10.977) < 0.01)
    }

    @Test func staleTimestampIsNotExtrapolated() throws {
        // Music flips `playing` with a days-old timestamp and rate 0; extrapolating would jump to the end.
        let line = #"{"type":"data","diff":false,"payload":{"playbackRate":0,"artist":"Malibu","album":"","elapsedTime":0.977,"#
            + #""timestamp":"2026-10-15T00:51:16Z","contentItemIdentifier":"219186::219198","#
            + #""bundleIdentifier":"com.apple.Music","playing":true,"title":"Iliad II (Light Over Me)","duration":131}}"#
        let parsed = try #require(track(line))
        #expect(parsed.isPlaying)
        #expect(abs(parsed.elapsed - 0.977) < 0.01)
    }

    @Test func browserTrackUsesTheParentApplication() throws {
        let line = #"{"type":"data","diff":false,"payload":{"playbackRate":1,"album":"","elapsedTime":0,"#
            + #""timestamp":"2026-10-18T13:58:56Z","bundleIdentifier":"com.apple.WebKit.GPU","#
            + #""parentApplicationBundleIdentifier":"com.apple.Safari","#
            + #""title":"Rick Astley - Never Gonna Give You Up (Official Video) (4K Remaster)","duration":213.061,"#
            + #""artist":"Rick Astley","contentItemIdentifier":"8033041","playing":true}}"#
        let parsed = try #require(track(line))
        #expect(parsed.sourceBundleId == "com.apple.Safari")
        #expect(parsed.title == "Never Gonna Give You Up (Official Video) (4K Remaster)")
    }

    @Test func pausedTrackHasZeroRate() throws {
        let line = #"{"type":"data","payload":{"playbackRate":1,"artist":"A","title":"T","bundleIdentifier":"com.example","playing":false,"duration":100,"elapsedTime":5}}"#
        let parsed = try #require(track(line))
        #expect(!parsed.isPlaying)
        #expect(parsed.elapsed == 5)
    }

    @Test func autoPlayPlaceholderAndUntaggedItemsAreNotTracks() {
        let placeholder = #"{"type":"data","diff":false,"payload":{"playbackRate":0,"artist":"","album":"","elapsedTime":0,"#
            + #""bundleIdentifier":"com.apple.Music","title":"AutoPlay","contentItemIdentifier":"PLACEHOLDER=219998::219999","#
            + #""playing":true}}"#
        #expect(parse(placeholder) == .nothingPlaying)
        let untagged = #"{"type":"data","payload":{"title":"Some video","artist":"","bundleIdentifier":"com.example","playing":true}}"#
        #expect(parse(untagged) == .nothingPlaying)
    }

    @Test func missingDurationIsTreatedAsUnknown() throws {
        // v0.7.7 drops non-finite numbers, so an infinite live-stream duration arrives as no key at all.
        let line = #"{"type":"data","payload":{"artist":"A","title":"Live stream","bundleIdentifier":"com.example","playing":true,"playbackRate":1,"elapsedTime":12}}"#
        let parsed = try #require(track(line))
        #expect(parsed.duration == 0)
        #expect(parsed.elapsed == 12)
    }
}
