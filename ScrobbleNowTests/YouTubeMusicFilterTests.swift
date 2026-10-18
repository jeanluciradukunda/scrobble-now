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
