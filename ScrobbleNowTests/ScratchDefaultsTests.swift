import Foundation
import Testing

struct ScratchDefaultsTests {
    @Test func releasingTheSuiteLeavesNoPlistBehind() {
        var defaults: ScratchDefaults? = ScratchDefaults()
        defaults?.store.set("x", forKey: "k")
        defaults?.store.synchronize()
        let url = defaults!.fileURL
        defaults = nil
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
