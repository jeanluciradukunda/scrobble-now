import Foundation
import Testing
@testable import Scrobble_Now

private typealias LastFMError = LastFMService.LastFMError

struct LastFMResponseTests {
    @Test func errorInBodyWinsOverHTTP200() {
        let body = Data(#"{"error":9,"message":"Invalid session key"}"#.utf8)
        #expect(throws: LastFMError.api(code: 9, message: "Invalid session key")) {
            try LastFMService.checkResponse(data: body, statusCode: 200)
        }
    }

    @Test func non200WithoutErrorBodyIsARequestFailure() {
        #expect(throws: LastFMError.requestFailed) {
            try LastFMService.checkResponse(data: Data("<html>".utf8), statusCode: 503)
        }
    }

    @Test func ignoredScrobbleIsNotASuccess() {
        let body = Data(#"""
        {"scrobbles":{"scrobble":{"ignoredMessage":{"code":"1","#text":"Artist ignored"}},"@attr":{"ignored":1,"accepted":0}}}
        """#.utf8)
        #expect(throws: LastFMError.ignored(code: 1)) { try LastFMService.checkScrobbleAccepted(body) }
    }

    @Test func acceptedScrobblePasses() throws {
        let body = Data(#"""
        {"scrobbles":{"scrobble":{"ignoredMessage":{"code":"0","#text":""}},"@attr":{"ignored":0,"accepted":1}}}
        """#.utf8)
        try LastFMService.checkScrobbleAccepted(body)
    }

    @Test func dispositionFollowsTheErrorCodeTable() {
        #expect(LastFMError.requestFailed.disposition == .retry)
        #expect(LastFMError.api(code: 11, message: "").disposition == .retry)
        #expect(LastFMError.api(code: 16, message: "").disposition == .retry)
        #expect(LastFMError.api(code: 29, message: "").disposition == .retry)
        #expect(LastFMError.api(code: 9, message: "").disposition == .keepUntilFixed)
        #expect(LastFMError.notAuthenticated.disposition == .keepUntilFixed)
        #expect(LastFMError.api(code: 8, message: "").disposition == .retry)
        #expect(LastFMError.ignored(code: 5).disposition == .retry)
        for code in [4, 10, 13, 26] {
            #expect(LastFMError.api(code: code, message: "").disposition == .keepUntilFixed)
        }
        #expect(LastFMError.api(code: 6, message: "").disposition == .drop)
        #expect(LastFMError.ignored(code: 1).disposition == .drop)
        #expect(LastFMError.ignored(code: 3).disposition == .drop)
    }

    @Test func scrobbleWithoutASessionThrows() async {
        let lastfm = LastFMService(sessionKey: { nil })
        await #expect(throws: LastFMError.notAuthenticated) {
            try await lastfm.scrobble(artist: "A", track: "T", album: "", timestamp: 1)
        }
        await #expect(throws: LastFMError.notAuthenticated) {
            try await lastfm.updateNowPlaying(artist: "A", track: "T", album: "")
        }
    }
}

private final class Flag: @unchecked Sendable {
    var raised = false
}

private final class InvalidSessionStub: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool { request.url?.host == "ws.audioscrobbler.com" }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"error":9,"message":"Invalid session key"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct LastFMInvalidSessionTests {
    @Test func error9ClearsTheStoredSession() async {
        URLProtocol.registerClass(InvalidSessionStub.self)
        defer { URLProtocol.unregisterClass(InvalidSessionStub.self) }
        let cleared = Flag()
        let lastfm = LastFMService(sessionKey: { "dead" }, invalidateSession: { cleared.raised = true })

        await #expect(throws: LastFMService.LastFMError.api(code: 9, message: "Invalid session key")) {
            try await lastfm.scrobble(artist: "A", track: "T", album: "", timestamp: 1)
        }
        #expect(cleared.raised)
    }
}
