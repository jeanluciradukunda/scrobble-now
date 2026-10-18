import Testing
@testable import Scrobble_Now

struct AppUpdaterTests {
    @Test func updaterRunsOnlyWithAPublicKey() {
        #expect(!AppUpdater.isConfigured(publicKey: nil))
        #expect(!AppUpdater.isConfigured(publicKey: ""))
        #expect(!AppUpdater.isConfigured(publicKey: "  "))
        #expect(AppUpdater.isConfigured(publicKey: "pfIShU4dEXqPd5ObYNfDBiQWcXozk7estwzTnF9BamQ="))
    }

    @MainActor
    @Test func thisBuildHasNoKeySoUpdatesAreOff() {
        #expect(!AppUpdater.shared.isConfigured)
    }
}

struct UpdateReminderTests {
    @Test func menuBarAppOptsIntoGentleReminders() {
        #expect(UpdateReminderDelegate().supportsGentleScheduledUpdateReminders)
    }
}

#if os(macOS)
import AppKit

struct UpdateBadgeSymbolTests {
    @Test func badgeSymbolExists() {
        #expect(NSImage(systemSymbolName: "waveform.badge.exclamationmark", accessibilityDescription: nil) != nil)
    }
}
#endif
