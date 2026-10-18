import Foundation
import Testing
@testable import Scrobble_Now

private actor GatedScrobbler: Scrobbling {
    private(set) var calls = 0
    private var gate: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func scrobble(artist: String, track: String, album: String, timestamp: Int) async throws {
        calls += 1
        if calls == 1 {
            started?.resume()
            await withCheckedContinuation { gate = $0 }
        }
    }

    func waitUntilFirstCallStarts() async {
        if calls > 0 { return }
        await withCheckedContinuation { started = $0 }
    }

    func open() {
        gate?.resume()
        gate = nil
    }
}

struct ScrobbleQueueTests {
    private func makeCache() -> ScrobbleCache {
        ScrobbleCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func entry(_ track: String, at timestamp: Int) -> ScrobbleCacheEntry {
        ScrobbleCacheEntry(artist: "A", track: track, album: "", timestamp: timestamp)
    }

    @Test func entryQueuedDuringARetryPassIsKept() async {
        let cache = makeCache()
        let scrobbler = GatedScrobbler()
        await cache.queueForRetry(entry("first", at: 1))

        let pass = Task { await cache.retryPending(using: scrobbler) }
        await scrobbler.waitUntilFirstCallStarts()
        await cache.queueForRetry(entry("queued mid-pass", at: 2))
        await scrobbler.open()
        _ = await pass.value

        #expect(await cache.pendingCount() == 1)
    }

    @Test func overlappingRetryPassesDoNotSendTwice() async {
        let cache = makeCache()
        let scrobbler = GatedScrobbler()
        await cache.queueForRetry(entry("only", at: 1))

        let first = Task { await cache.retryPending(using: scrobbler) }
        await scrobbler.waitUntilFirstCallStarts()
        let second = await cache.retryPending(using: scrobbler)
        await scrobbler.open()
        let firstResult = await first.value

        #expect(second.succeeded == 0)
        #expect(firstResult.succeeded == 1)
        #expect(await scrobbler.calls == 1)
    }
}
