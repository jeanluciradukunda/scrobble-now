import Foundation
import Testing
@testable import Scrobble_Now

struct FailedScrobblesTests {
    private func entry(_ track: String) -> ScrobbleCacheEntry {
        ScrobbleCacheEntry(artist: "A", track: track, album: "", timestamp: 1)
    }

    @Test func givenUpScrobblesAreListedNewestFirstAndCanBeCleared() async {
        let cache = ScrobbleCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await cache.logHistory(entry("sent"), success: true)
        await cache.logHistory(entry("first failure"), success: false)
        await cache.logHistory(entry("second failure"), success: false)

        #expect(await cache.failedScrobbles().map(\.track) == ["second failure", "first failure"])

        await cache.clearFailed()
        #expect(await cache.failedScrobbles().isEmpty)
        #expect(await cache.successCount() == 1)
    }
}
