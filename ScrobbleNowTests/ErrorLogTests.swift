import Foundation
import Testing
@testable import Scrobble_Now

struct ErrorLogTests {
    @Test func aFailedRequestIsLoggedWithoutItsURL() {
        let failing = "https://ws.audioscrobbler.com/2.0/?method=user.getTopAlbums&api_key=dummy-key-123&api_sig=dummy-sig"
        let error = URLError(.timedOut, userInfo: [NSURLErrorFailingURLStringErrorKey: failing,
                                                   NSURLErrorFailingURLErrorKey: URL(string: failing)!])
        let line = ErrorLog.line("Stats load error", error)
        #expect(line.hasPrefix("Stats load error: "))
        #expect(!line.contains("dummy-key-123"))
        #expect(!line.contains("dummy-sig"))
    }
}
