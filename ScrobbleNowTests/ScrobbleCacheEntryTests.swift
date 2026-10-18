import Foundation
import Testing
@testable import Scrobble_Now

struct ScrobbleCacheEntryTests {
    @Test func idCombinesArtistTrackAndTimestamp() {
        let entry = ScrobbleCacheEntry(artist: "A", track: "T", album: "X", timestamp: 5)
        #expect(entry.id == "A|T|5")
    }

    @Test func codableRoundTripKeepsRetryCount() throws {
        let entry = ScrobbleCacheEntry(artist: "A", track: "T", album: "X", timestamp: 5, retryCount: 3)
        let decoded = try JSONDecoder().decode(ScrobbleCacheEntry.self, from: JSONEncoder().encode(entry))
        #expect(decoded.retryCount == 3)
        #expect(decoded.id == entry.id)
    }

    @Test func progressClampsAtOne() {
        let track = SystemNowPlaying(title: "t", artist: "a", album: "", duration: 100, elapsed: 250, playbackRate: 1,
                                     artwork: nil, sourceBundleId: "b", sourceAppName: "n", timestamp: Date())
        #expect(track.progress == 1)
        #expect(track.durationFormatted == "1:40")
    }
}
