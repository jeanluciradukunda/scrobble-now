import Foundation
import Testing
@testable import Scrobble_Now

struct ArtworkSaverTests {
    @Test func namesAreSanitisedAndNumbered() {
        #expect(ArtworkSaver.fileNames(count: 1, named: "AC/DC: Live") == ["AC-DC- Live.jpg"])
        #expect(ArtworkSaver.fileNames(count: 2, named: "X") == ["X - 1.jpg", "X - 2.jpg"])
    }

    @Test func reportsOnlyFilesActuallyWritten() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #expect(ArtworkSaver.save([Data([1]), Data([2])], named: "Album", in: folder) == 2)

        let missing = folder.appendingPathComponent("does-not-exist")
        #expect(ArtworkSaver.save([Data([1])], named: "Album", in: missing) == 0)
    }
}
