import Foundation
import Testing
@testable import Scrobble_Now

@Suite(.serialized)
struct SecretSeedingTests {
    @Test func placeholderNeverOverwritesAStoredKey() {
        let defaults = ScratchDefaults("SecretSeeding")
        defaults.store.set("real-key", forKey: "sn_secret_lastfm_api_key")
        KeychainService.seed([(.lastfmApiKey, "YOUR_LASTFM_API_KEY_HERE")], into: defaults.store)
        #expect(defaults.store.string(forKey: "sn_secret_lastfm_api_key") == "real-key")
    }

    @Test func placeholderIsNeverStored() {
        let defaults = ScratchDefaults("SecretSeeding")
        KeychainService.seed([(.discogsToken, "YOUR_DISCOGS_TOKEN_HERE")], into: defaults.store)
        #expect(defaults.store.string(forKey: "sn_secret_discogs_token") == nil)
    }

    @Test func storedPlaceholderIsRemoved() {
        let defaults = ScratchDefaults("SecretSeeding")
        defaults.store.set("YOUR_LASTFM_SHARED_SECRET_HERE", forKey: "sn_secret_lastfm_shared_secret")
        KeychainService.seed([(.lastfmSharedSecret, "YOUR_LASTFM_SHARED_SECRET_HERE")], into: defaults.store)
        #expect(defaults.store.string(forKey: "sn_secret_lastfm_shared_secret") == nil)
    }

    @Test func realPlistValueStillWins() {
        let defaults = ScratchDefaults("SecretSeeding")
        defaults.store.set("old", forKey: "sn_secret_lastfm_api_key")
        KeychainService.seed([(.lastfmApiKey, "new")], into: defaults.store)
        #expect(defaults.store.string(forKey: "sn_secret_lastfm_api_key") == "new")
    }
}
