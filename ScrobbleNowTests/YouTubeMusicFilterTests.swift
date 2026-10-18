import Foundation
import Testing
@testable import Scrobble_Now

struct YouTubeMusicFilterTests {
    @Test func splitsArtistAndTrack() {
        let parsed = YouTubeMusicFilter.parseVideoTitle("Radiohead - Creep (Official Video)")
        #expect(parsed.artist == "Radiohead")
        #expect(parsed.track == "Creep")
    }

    @Test func keepsRemixSuffixInTrack() {
        let parsed = YouTubeMusicFilter.parseVideoTitle("Artist - Song - Remix")
        #expect(parsed.track == "Song - Remix")
    }

    @Test func byPatternSwapsOrder() {
        let parsed = YouTubeMusicFilter.parseVideoTitle("Creep by Radiohead")
        #expect(parsed.artist == "Radiohead")
        #expect(parsed.track == "Creep")
    }

    @Test func noSeparatorLeavesArtistEmpty() {
        let parsed = YouTubeMusicFilter.parseVideoTitle("Just a title")
        #expect(parsed.artist.isEmpty)
        #expect(parsed.track == "Just a title")
    }

    @Test func extractsVideoIds() {
        #expect(YouTubeMusicFilter.extractVideoId(from: "https://www.youtube.com/watch?v=abc123&t=5") == "abc123")
        #expect(YouTubeMusicFilter.extractVideoId(from: "https://youtu.be/xyz?si=1") == "xyz")
        #expect(YouTubeMusicFilter.extractVideoId(from: "https://example.com") == nil)
    }
}

extension YouTubeMusicFilterTests {
    @Test func vParamInsideOtherQueryKeyIsNotAVideoId() {
        #expect(YouTubeMusicFilter.extractVideoId(from: "https://www.youtube.com/watch?rev=1&v=real") == "real")
        #expect(YouTubeMusicFilter.extractVideoId(from: "https://www.youtube.com/watch?nav=1") == nil)
    }
}

@Suite(.serialized)
struct YouTubeCategoryCheckTests {
    @Test func networkErrorIsNotCachedAsNonMusic() async {
        URLProtocol.registerClass(StubProtocol.self)
        defer { URLProtocol.unregisterClass(StubProtocol.self) }
        let filter = YouTubeMusicFilter()

        StubProtocol.categoryPage = nil
        #expect(await !filter.check(videoId: "abc").isMusic)

        StubProtocol.categoryPage = #"<html>"category":"Music"</html>"#
        #expect(await filter.check(videoId: "abc").isMusic)
    }
}

private final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var categoryPage: String?

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix("youtube.com") == true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard request.url?.host == "www.youtube.com", let page = Self.categoryPage, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(page.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
