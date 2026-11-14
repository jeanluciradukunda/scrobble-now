import Foundation
import Testing
@testable import Scrobble_Now

struct DiscogsPageURLTests {
    @Test func aFullReleaseURLIsKept() {
        let url = DiscogsService.pageURL(uri: "https://www.discogs.com/release/249504-Rick-Astley-Never-Gonna-Give-You-Up")
        #expect(url?.absoluteString == "https://www.discogs.com/release/249504-Rick-Astley-Never-Gonna-Give-You-Up")
    }

    @Test func aPathIsJoinedToTheDiscogsHost() {
        #expect(DiscogsService.pageURL(uri: "/release/249504")?.absoluteString == "https://www.discogs.com/release/249504")
    }

    @Test func aURIThatLeavesDiscogsIsDropped() {
        for uri in ["@example.com/release/1", "https://example.com/release/1", "http://www.discogs.com/release/1", "file:///etc/hosts"] {
            #expect(DiscogsService.pageURL(uri: uri) == nil, "\(uri)")
        }
    }
}
