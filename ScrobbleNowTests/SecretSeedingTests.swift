import Foundation
import Testing
@testable import Scrobble_Now

struct SecretSeedingTests {
    private func freshStore() -> UserDefaults {
        let name = "SecretSeedingTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return store
    }

    @Test func placeholderNeverOverwritesAStoredKey() {
        let store = freshStore()
        store.set("real-key", forKey: "sn_secret_lastfm_api_key")
        KeychainService.seed([(.lastfmApiKey, "YOUR_LASTFM_API_KEY_HERE")], into: store)
        #expect(store.string(forKey: "sn_secret_lastfm_api_key") == "real-key")
    }

    @Test func placeholderIsNeverStored() {
        let store = freshStore()
        KeychainService.seed([(.discogsToken, "YOUR_DISCOGS_TOKEN_HERE")], into: store)
        #expect(store.string(forKey: "sn_secret_discogs_token") == nil)
    }

    @Test func storedPlaceholderIsRemoved() {
        let store = freshStore()
        store.set("YOUR_LASTFM_SHARED_SECRET_HERE", forKey: "sn_secret_lastfm_shared_secret")
        KeychainService.seed([(.lastfmSharedSecret, "YOUR_LASTFM_SHARED_SECRET_HERE")], into: store)
        #expect(store.string(forKey: "sn_secret_lastfm_shared_secret") == nil)
    }

    @Test func realPlistValueStillWins() {
        let store = freshStore()
        store.set("old", forKey: "sn_secret_lastfm_api_key")
        KeychainService.seed([(.lastfmApiKey, "new")], into: store)
        #expect(store.string(forKey: "sn_secret_lastfm_api_key") == "new")
    }
}
