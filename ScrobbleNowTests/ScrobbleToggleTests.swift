import Testing
@testable import Scrobble_Now

@MainActor
struct ScrobbleToggleTests {
    @Test func turningScrobblingOffInSettingsDisablesTheService() {
        let settings = SettingsManager.shared
        let original = settings.scrobbleEnabled
        defer { settings.scrobbleEnabled = original }

        settings.scrobbleEnabled = false
        #expect(!SystemScrobbleService.shared.isEnabled)

        settings.scrobbleEnabled = true
        #expect(SystemScrobbleService.shared.isEnabled)
    }
}
