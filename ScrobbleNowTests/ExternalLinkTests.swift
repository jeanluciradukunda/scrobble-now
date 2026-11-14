import Foundation
import Testing
@testable import Scrobble_Now

struct ExternalLinkTests {
    @Test func httpsLinksOpen() {
        #expect(ExternalLink.canOpen(URL(string: "https://www.last.fm/music/Radiohead")!))
        #expect(ExternalLink.canOpen(URL(string: "HTTPS://music.apple.com/album/1")!))
    }

    @Test func otherSchemesFromAnAPIReplyNeverOpen() {
        for link in ["file:///Applications/Calculator.app", "http://www.last.fm/music/x", "someapp://do-something", "https:///no-host"] {
            #expect(!ExternalLink.canOpen(URL(string: link)!), "\(link)")
        }
    }
}
