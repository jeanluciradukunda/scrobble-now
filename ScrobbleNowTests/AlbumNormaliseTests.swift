import Testing
@testable import Scrobble_Now

struct AlbumNormaliseTests {
    @Test func keepsNonLatinTitles() {
        #expect(AlbumDiscoveryService.normalize("東京") == "東京")
        #expect(AlbumDiscoveryService.normalize("Кино") == "кино")
        #expect(AlbumDiscoveryService.normalize("Ἑλλάς") == "ελλας")
        #expect(AlbumDiscoveryService.normalize("हिन्दी") == "हिन्दी")
    }

    @Test func distinctNonLatinTitlesStayDistinct() {
        #expect(AlbumDiscoveryService.normalize("東京") != AlbumDiscoveryService.normalize("大阪"))
    }

    @Test func latinBehaviourIsUnchanged() {
        #expect(AlbumDiscoveryService.normalize("  OK Computer (Deluxe)! ") == "ok computer deluxe")
        #expect(AlbumDiscoveryService.normalize("Sigur Rós") == "sigur ros")
        #expect(AlbumDiscoveryService.normalize("Bjørk") == "bjørk")
    }
}
