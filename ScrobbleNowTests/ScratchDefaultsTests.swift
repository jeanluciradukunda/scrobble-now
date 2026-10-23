import Foundation
import Testing

struct ScratchDefaultsTests {
    @Test func aScratchSuiteStartsEmptyAndIsEmptiedWhenReleased() {
        var defaults: ScratchDefaults? = ScratchDefaults("ScratchDefaultsTests")
        defaults?.store.set("x", forKey: "k")
        defaults = nil
        let reopened = ScratchDefaults("ScratchDefaultsTests")
        #expect(reopened.store.string(forKey: "k") == nil)
    }
}
