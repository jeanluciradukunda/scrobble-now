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
        #expect(LastFMError.api(code: 9, message: "").disposition == .keepUntilAuthorised)
        #expect(LastFMError.notAuthenticated.disposition == .keepUntilAuthorised)
        #expect(LastFMError.api(code: 6, message: "").disposition == .drop)
        #expect(LastFMError.ignored(code: 1).disposition == .drop)
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
