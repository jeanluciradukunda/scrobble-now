import Foundation
import Testing
@testable import Scrobble_Now

private final class LoveStub: URLProtocol {
    nonisolated(unsafe) static var lastBody = ""
    nonisolated(unsafe) static var reply = #"{}"#

    override static func canInit(with request: URLRequest) -> Bool { request.url?.host == "ws.audioscrobbler.com" }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            Self.lastBody = String(bytes: data, encoding: .utf8) ?? ""
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.reply.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite(.serialized)
struct LastFMLoveTests {
    @Test func loveSendsASignedTrackLove() async throws {
        URLProtocol.registerClass(LoveStub.self)
        defer { URLProtocol.unregisterClass(LoveStub.self) }
        LoveStub.reply = #"{}"#
        let lastfm = LastFMService(sessionKey: { "session" }, invalidateSession: {})

        try await lastfm.loveTrack(artist: "Simon & Garfunkel", track: "America")

        #expect(LoveStub.lastBody.contains("method=track.love"))
        #expect(LoveStub.lastBody.contains("artist=Simon%20%26%20Garfunkel"))
        #expect(LoveStub.lastBody.contains("sk=session"))
        #expect(LoveStub.lastBody.contains("api_sig="))
    }

    @Test func unloveSendsTrackUnlove() async throws {
        URLProtocol.registerClass(LoveStub.self)
        defer { URLProtocol.unregisterClass(LoveStub.self) }
        LoveStub.reply = #"{}"#
        let lastfm = LastFMService(sessionKey: { "session" }, invalidateSession: {})

        try await lastfm.unloveTrack(artist: "A", track: "T")

        #expect(LoveStub.lastBody.contains("method=track.unlove"))
    }

    @Test func loveReportsLastFMErrors() async {
        URLProtocol.registerClass(LoveStub.self)
        defer { URLProtocol.unregisterClass(LoveStub.self) }
        LoveStub.reply = #"{"error":6,"message":"Track not found"}"#
        let lastfm = LastFMService(sessionKey: { "session" }, invalidateSession: {})

        await #expect(throws: LastFMService.LastFMError.api(code: 6, message: "Track not found")) {
            try await lastfm.loveTrack(artist: "A", track: "T")
        }
    }

    @Test func loveWithoutASessionThrows() async {
        let lastfm = LastFMService(sessionKey: { nil }, invalidateSession: {})
        await #expect(throws: LastFMService.LastFMError.notAuthenticated) {
            try await lastfm.loveTrack(artist: "A", track: "T")
        }
    }

    @Test func recentTracksCanBeBoundedByTime() {
        let params = LastFMService.recentTracksParams(user: "jean", limit: 200, from: Date(timeIntervalSince1970: 100),
                                                      to: Date(timeIntervalSince1970: 200))
        #expect(params["from"] == "100")
        #expect(params["to"] == "200")
        #expect(LastFMService.recentTracksParams(user: "jean", limit: 30, from: nil, to: nil)["from"] == nil)
    }
}
