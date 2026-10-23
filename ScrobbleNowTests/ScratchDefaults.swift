import Foundation

/// A UserDefaults suite for tests under a fixed name. A fresh UUID-named suite per test left a new plist
/// in ~/Library/Preferences on every run: cfprefsd writes the file after the test has finished, so deleting
/// it does not help. Reusing one name per test suite keeps it to a single file that is emptied before and
/// after use; suites that use it must be `.serialized`.
final class ScratchDefaults {
    let name: String
    let store: UserDefaults

    init(_ suite: String) {
        name = "ScrobbleNowTests.\(suite)"
        store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
    }

    deinit {
        store.removePersistentDomain(forName: name)
    }
}
