import Testing
@testable import Scrobble_Now

struct PodcastFilterTests {
    @Test func recognisesPodcastApps() {
        #expect(SystemScrobbleService.isPodcastApp("com.apple.podcasts"))
        #expect(SystemScrobbleService.isPodcastApp("fm.overcast.overcast"))
        #expect(SystemScrobbleService.isPodcastApp("au.com.shiftyjelly.PocketCasts"))
        #expect(SystemScrobbleService.isPodcastApp("co.supertop.Castro-2"))
        #expect(!SystemScrobbleService.isPodcastApp("com.spotify.client"))
        #expect(!SystemScrobbleService.isPodcastApp("com.apple.Music"))
    }
}
