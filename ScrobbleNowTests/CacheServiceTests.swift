import Testing
@testable import Scrobble_Now

struct CacheServiceTests {
    @Test func clearEmptiesTheAlbumCache() async {
        let cache = CacheService()
        let album = AlbumDetail(albumName: "A", artistName: "B", artworkURL: nil, allArtworkURLs: [], tracks: [],
                                tags: [], listeners: nil, playcount: nil, wikiSummary: nil, appleMusicURL: nil,
                                lastfmURL: nil, musicbrainzURL: nil, discogsURL: nil, source: .lastfm,
                                confidenceScore: 0, releaseYear: nil)
        await cache.cacheAlbum(key: "B|A", album: album)
        await cache.clear()
        #expect(await cache.getCachedAlbum(key: "B|A") == nil)
    }
}
