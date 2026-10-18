import Foundation
import Testing
@testable import Scrobble_Now

struct LastFMCredentialsTests {
    private func store(bundledKey: String = "bundled-key", bundledSecret: String = "bundled-secret") -> UserDefaults {
        let name = "LastFMCredentialsTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        store.set(bundledKey, forKey: "sn_secret_lastfm_api_key")
        store.set(bundledSecret, forKey: "sn_secret_lastfm_shared_secret")
        store.set("session", forKey: "sn_secret_lastfm_session_key")
        return store
    }

    @Test func bundledPairIsUsedByDefault() {
        let credentials = KeychainService.lastfmCredentials(in: store())
        #expect(credentials.apiKey == "bundled-key")
        #expect(credentials.secret == "bundled-secret")
        #expect(!credentials.isOwn)
    }

    @Test func ownPairWinsOnlyWhenComplete() {
        let defaults = store()
        defaults.set("mine", forKey: "sn_secret_own_lastfm_api_key")
        #expect(KeychainService.lastfmCredentials(in: defaults).apiKey == "bundled-key")

        defaults.set("my-secret", forKey: "sn_secret_own_lastfm_shared_secret")
        let credentials = KeychainService.lastfmCredentials(in: defaults)
        #expect(credentials.apiKey == "mine")
        #expect(credentials.secret == "my-secret")
        #expect(credentials.isOwn)
    }

    @Test func switchingKeysSignsOut() {
        let defaults = store()
        KeychainService.setOwnLastfmCredentials(apiKey: " mine ", secret: "my-secret", in: defaults)
        #expect(KeychainService.lastfmCredentials(in: defaults).apiKey == "mine")
        #expect(defaults.string(forKey: "sn_secret_lastfm_session_key") == nil)
    }

    @Test func savingTheSameKeyKeepsTheSession() {
        let defaults = store()
        KeychainService.setOwnLastfmCredentials(apiKey: "", secret: "", in: defaults)
        #expect(defaults.string(forKey: "sn_secret_lastfm_session_key") == "session")
    }

    @Test func clearingOwnKeyFallsBackToBundledAndSignsOut() {
        let defaults = store()
        KeychainService.setOwnLastfmCredentials(apiKey: "mine", secret: "my-secret", in: defaults)
        defaults.set("new-session", forKey: "sn_secret_lastfm_session_key")
        KeychainService.setOwnLastfmCredentials(apiKey: "", secret: "", in: defaults)
        #expect(KeychainService.lastfmCredentials(in: defaults).apiKey == "bundled-key")
        #expect(defaults.string(forKey: "sn_secret_lastfm_session_key") == nil)
    }
}
