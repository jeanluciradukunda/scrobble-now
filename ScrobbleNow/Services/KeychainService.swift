import Foundation

struct KeychainService {
    private static let defaults = UserDefaults.standard
    private static let prefix = "sn_secret_"

    enum Key: String, CaseIterable {
        case lastfmApiKey = "lastfm_api_key"
        case lastfmSharedSecret = "lastfm_shared_secret"
        case lastfmSessionKey = "lastfm_session_key"
        case discogsToken = "discogs_token"

        var displayName: String {
            switch self {
            case .lastfmApiKey: return "Last.fm API Key"
            case .lastfmSharedSecret: return "Last.fm Shared Secret"
            case .lastfmSessionKey: return "Last.fm Session Key"
            case .discogsToken: return "Discogs Token"
            }
        }

        var isUserEditable: Bool {
            switch self {
            case .lastfmSessionKey: return false
            default: return true
            }
        }
    }

    static func get(_ key: Key) -> String? {
        defaults.string(forKey: prefix + key.rawValue)
    }

    @discardableResult
    static func set(_ key: Key, value: String) -> Bool {
        defaults.set(value, forKey: prefix + key.rawValue)
        return true
    }

    @discardableResult
    static func delete(_ key: Key) -> Bool {
        defaults.removeObject(forKey: prefix + key.rawValue)
        return true
    }

    static func bootstrapDefaults() {
        let defaults: [(Key, String)] = loadSecretsFromPlist()
        for (key, value) in defaults where !value.isEmpty {
            // Always overwrite from Secrets.plist — the plist is the source of truth
            let existing = get(key) ?? ""
            if existing.isEmpty || existing != value {
                set(key, value: value)
            }
        }
    }

    // MARK: - Convenience
    static var lastfmApiKey: String { Self.get(.lastfmApiKey) ?? "" }
    static var lastfmSharedSecret: String { Self.get(.lastfmSharedSecret) ?? "" }
    static var lastfmSessionKey: String? { Self.get(.lastfmSessionKey) }
    static var discogsToken: String { Self.get(.discogsToken) ?? "" }

    // MARK: - Load from Secrets.plist
    private static func loadSecretsFromPlist() -> [(Key, String)] {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else {
            print("[KeychainService] ⚠️ Secrets.plist not found — API keys will be empty.")
            return []
        }

        return [
            (.lastfmApiKey, dict["LASTFM_API_KEY"] ?? ""),
            (.lastfmSharedSecret, dict["LASTFM_SHARED_SECRET"] ?? ""),
            (.discogsToken, dict["DISCOGS_TOKEN"] ?? ""),
        ]
    }
}
