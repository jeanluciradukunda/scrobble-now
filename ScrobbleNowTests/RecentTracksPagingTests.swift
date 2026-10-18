import Foundation
import Testing
@testable import Scrobble_Now

private final class PagingStub: URLProtocol {
    nonisolated(unsafe) static var requestedPages: [String] = []

    override static func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "ws.audioscrobbler.com" && request.url?.query?.contains("getRecentTracks") == true
    }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "page" }?.value ?? "1"
        Self.requestedPages.append(page)
        let body: String
        if page == "1" {
            let tracks = (0..<200).map { ##"{"name":"t\##($0)","artist":{"name":"A"},"album":{"#text":""},"date":{"uts":"\##(1_760_000_000 + $0)"}}"## }
            body = ##"{"recenttracks":{"track":[\##(tracks.joined(separator: ","))]}}"##
        } else {
            body = #"{"error":29,"message":"Rate limit exceeded"}"#
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct RecentTracksPagingTests {
    @Test func anErrorPageStopsPagingWithAnErrorInsteadOfTruncating() async {
        URLProtocol.registerClass(PagingStub.self)
        defer { URLProtocol.unregisterClass(PagingStub.self) }
        PagingStub.requestedPages = []
        let lastfm = LastFMService(sessionKey: { nil })
        await #expect(throws: LastFMService.LastFMError.api(code: 29, message: "Rate limit exceeded")) {
            _ = try await lastfm.getAllRecentTracks(user: "u", from: Date(timeIntervalSince1970: 0), to: Date())
        }
        #expect(PagingStub.requestedPages == ["1", "2"])
    }
}
