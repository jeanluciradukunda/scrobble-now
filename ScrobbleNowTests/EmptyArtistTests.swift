import Foundation
import Testing
@testable import Scrobble_Now

struct EmptyArtistTests {
    private let rules = ScrobbleRules(thresholdPercent: 50, minTrackDuration: 30)

    private func tab(artist: String, title: String) -> SystemNowPlaying {
        SystemNowPlaying(title: title, artist: artist, album: "", duration: 200, elapsed: 0, playbackRate: 1,
                         artwork: nil, sourceBundleId: "com.google.Chrome", sourceAppName: "Chrome",
                         timestamp: Date(timeIntervalSince1970: 0))
    }

    @Test func aBrowserTabWithNoArtistIsNeverScrobbled() {
        var engine = ScrobbleEngine()
        var now = Date(timeIntervalSince1970: 1_000_000)
        var scrobbles = engine.trackChanged(to: tab(artist: "", title: "YouTube"), now: now, rules: rules) { _ in true }
        for _ in 0..<300 {
            now = now.addingTimeInterval(1)
            scrobbles += engine.tick(isPlaying: true, now: now, rules: rules) { _ in true }
        }
        #expect(scrobbles.isEmpty)
    }

    @Test func artistAndTitleMustBothHaveText() {
        #expect(LastFMService.hasArtistAndTitle(artist: "Radiohead", title: "Creep"))
        #expect(!LastFMService.hasArtistAndTitle(artist: "", title: "YouTube"))
        #expect(!LastFMService.hasArtistAndTitle(artist: "  ", title: "Creep"))
        #expect(!LastFMService.hasArtistAndTitle(artist: "Radiohead", title: ""))
    }

    @Test func lastFMRefusesToSendAnEmptyArtist() async {
        let lastfm = LastFMService(sessionKey: { "session" })
        await #expect(throws: LastFMService.LastFMError.missingArtistOrTitle) {
            try await lastfm.scrobble(artist: "", track: "YouTube", album: "", timestamp: 1)
        }
        #expect(LastFMService.LastFMError.missingArtistOrTitle.disposition == .drop)
    }

    @Test func anEmptyArtistIsNeverQueuedForRetry() async {
        let cache = ScrobbleCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await cache.queueForRetry(ScrobbleCacheEntry(artist: "", track: "YouTube", album: "", timestamp: 1))
        #expect(await cache.pendingCount() == 0)
    }
}
