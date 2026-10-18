import Testing
@testable import Scrobble_Now

struct AlbumNormaliseTests {
    @Test func keepsNonLatinTitles() {
        #expect(AlbumNormalisation.normalize("東京") == "東京")
        #expect(AlbumNormalisation.normalize("Кино") == "кино")
        #expect(AlbumNormalisation.normalize("Ἑλλάς") == "ελλας")
        #expect(AlbumNormalisation.normalize("हिन्दी") == "हिन्दी")
    }

    @Test func distinctNonLatinTitlesStayDistinct() {
        #expect(AlbumNormalisation.normalize("東京") != AlbumNormalisation.normalize("大阪"))
    }

    @Test func latinBehaviourIsUnchanged() {
        #expect(AlbumNormalisation.normalize("  OK Computer (Deluxe)! ") == "ok computer deluxe")
        #expect(AlbumNormalisation.normalize("Sigur Rós") == "sigur ros")
        #expect(AlbumNormalisation.normalize("Bjørk") == "bjørk")
    }
}

struct TopAlbumDedupTests {
    private func entry(_ album: String, _ artist: String, _ plays: Int) -> TopAlbumEntry {
        TopAlbumEntry(albumName: album, artistName: artist, playcount: plays, artworkURL: nil, lastfmURL: nil)
    }

    @Test func editionSuffixesAreStripped() {
        #expect(AlbumNormalisation.withoutEdition("OK Computer (Remastered)") == "OK Computer")
        #expect(AlbumNormalisation.withoutEdition("Lover [Deluxe Edition]") == "Lover")
        #expect(AlbumNormalisation.withoutEdition("Thriller (25th Anniversary Edition)") == "Thriller")
        #expect(AlbumNormalisation.withoutEdition("Sweetener - EP") == "Sweetener")
        #expect(AlbumNormalisation.withoutEdition("Live (at Wembley)") == "Live (at Wembley)")
    }

    @Test func primaryArtistDropsFeatures() {
        #expect(AlbumNormalisation.primaryArtist("Kanye West & Travis Scott") == "Kanye West")
        #expect(AlbumNormalisation.primaryArtist("Drake feat. Rihanna") == "Drake")
        #expect(AlbumNormalisation.primaryArtist("Radiohead") == "Radiohead")
    }

    @Test func editionsMergeWithPlaysSummed() {
        let merged = AlbumNormalisation.mergingDuplicates([
            entry("Lover", "Taylor Swift", 40),
            entry("Folklore", "Taylor Swift", 30),
            entry("Lover (Deluxe)", "Taylor Swift", 25)
        ])
        #expect(merged.map(\.albumName) == ["Lover", "Folklore"])
        #expect(merged.first?.playcount == 65)
    }

    @Test func symbolOnlyTitlesStayDistinct() {
        let merged = AlbumNormalisation.mergingDuplicates([
            entry("÷", "Ed Sheeran", 50), entry("+", "Ed Sheeran", 30), entry("=", "Ed Sheeran", 20), entry("-", "Ed Sheeran", 10)
        ])
        #expect(merged.count == 4)
    }

    @Test func nonLatinAlbumsStayDistinct() {
        let merged = AlbumNormalisation.mergingDuplicates([entry("東京", "A", 5), entry("大阪", "A", 4)])
        #expect(merged.count == 2)
    }
}
