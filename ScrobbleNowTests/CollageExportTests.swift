import Foundation
import Testing
@testable import Scrobble_Now

struct CollageExportTests {
    @Test func writeReportsWhetherTheFileWasSaved() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #expect(CollageViewModel.write(Data([1]), to: folder.appendingPathComponent("c.png")))
        #expect(!CollageViewModel.write(Data([1]), to: folder.appendingPathComponent("missing/c.png")))
    }
}
