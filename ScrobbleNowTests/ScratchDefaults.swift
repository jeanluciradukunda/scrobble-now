import Foundation

/// A throwaway UserDefaults suite. Removing the domain empties it but leaves its plist in
/// ~/Library/Preferences, so the file is deleted too when the suite is released.
final class ScratchDefaults {
    let name = "ScrobbleNowTests.\(UUID().uuidString)"
    let store: UserDefaults

    init() {
        store = UserDefaults(suiteName: name)!
    }

    var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/\(name).plist")
    }

    deinit {
        store.removePersistentDomain(forName: name)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
