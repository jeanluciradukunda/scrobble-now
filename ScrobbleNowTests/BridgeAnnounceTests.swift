import Foundation
import Testing
@testable import Scrobble_Now

struct BridgeAnnounceTests {
    private func track(_ title: String, source: String = "com.spotify.client", rate: Double = 1) -> SystemNowPlaying {
        SystemNowPlaying(title: title, artist: "Artist", album: "", duration: 200, elapsed: 0, playbackRate: rate,
                         artwork: nil, sourceBundleId: source, sourceAppName: "App", timestamp: Date())
    }

    @Test func newTitleIsAnnounced() {
        #expect(MediaRemoteBridge.shouldAnnounce(existing: track("a"), incoming: track("b"), currentSource: "com.spotify.client"))
        #expect(MediaRemoteBridge.shouldAnnounce(existing: nil, incoming: track("a"), currentSource: nil))
    }

    @Test func sameTrackStillPlayingIsNotAnnounced() {
        #expect(!MediaRemoteBridge.shouldAnnounce(existing: track("a"), incoming: track("a"), currentSource: "com.spotify.client"))
    }

    @Test func resumingOnTheCurrentSourceIsNotAnnounced() {
        #expect(!MediaRemoteBridge.shouldAnnounce(existing: track("a", rate: 0), incoming: track("a"),
                                                  currentSource: "com.spotify.client"))
    }

    @Test func switchingBackToAPausedSourceIsAnnounced() {
        #expect(MediaRemoteBridge.shouldAnnounce(existing: track("a", rate: 0), incoming: track("a"),
                                                 currentSource: "com.apple.Music"))
    }

    @Test func pausedUpdatesAreNeverAnnounced() {
        #expect(!MediaRemoteBridge.shouldAnnounce(existing: nil, incoming: track("a", rate: 0), currentSource: nil))
    }
}
