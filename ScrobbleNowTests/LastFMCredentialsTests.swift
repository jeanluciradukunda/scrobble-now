import Foundation
import Testing
@testable import Scrobble_Now

@Suite(.serialized)
struct LastFMCredentialsTests {
    private func scratch(bundledKey: String = "bundled-key", bundledSecret: String = "bundled-secret") -> ScratchDefaults {
        let scratch = ScratchDefaults("LastFMCredentials")
        let store = scratch.store
        store.set(bundledKey, forKey: "sn_secret_lastfm_api_key")
        store.set(bundledSecret, forKey: "sn_secret_lastfm_shared_secret")
        store.set("session", forKey: "sn_secret_lastfm_session_key")
        return scratch
    }

    @Test func bundledPairIsUsedByDefault() {
        let defaults = scratch()
        let credentials = KeychainService.lastfmCredentials(in: defaults.store)
        #expect(credentials.apiKey == "bundled-key")
        #expect(credentials.secret == "bundled-secret")
        #expect(!credentials.isOwn)
    }

    @Test func ownPairWinsOnlyWhenComplete() {
        let defaults = scratch()
        defaults.store.set("mine", forKey: "sn_secret_own_lastfm_api_key")
        #expect(KeychainService.lastfmCredentials(in: defaults.store).apiKey == "bundled-key")

        defaults.store.set("my-secret", forKey: "sn_secret_own_lastfm_shared_secret")
        let credentials = KeychainService.lastfmCredentials(in: defaults.store)
        #expect(credentials.apiKey == "mine")
        #expect(credentials.secret == "my-secret")
        #expect(credentials.isOwn)
    }

    @Test func switchingKeysSignsOut() {
        let defaults = scratch()
        KeychainService.setOwnLastfmCredentials(apiKey: " mine ", secret: "my-secret", in: defaults.store)
        #expect(KeychainService.lastfmCredentials(in: defaults.store).apiKey == "mine")
        #expect(defaults.store.string(forKey: "sn_secret_lastfm_session_key") == nil)
    }

    @Test func savingTheSameKeyKeepsTheSession() {
        let defaults = scratch()
        KeychainService.setOwnLastfmCredentials(apiKey: "", secret: "", in: defaults.store)
        #expect(defaults.store.string(forKey: "sn_secret_lastfm_session_key") == "session")
    }

    @Test func clearingOwnKeyFallsBackToBundledAndSignsOut() {
        let defaults = scratch()
        KeychainService.setOwnLastfmCredentials(apiKey: "mine", secret: "my-secret", in: defaults.store)
        defaults.store.set("new-session", forKey: "sn_secret_lastfm_session_key")
        KeychainService.setOwnLastfmCredentials(apiKey: "", secret: "", in: defaults.store)
        #expect(KeychainService.lastfmCredentials(in: defaults.store).apiKey == "bundled-key")
        #expect(defaults.store.string(forKey: "sn_secret_lastfm_session_key") == nil)
    }
}
