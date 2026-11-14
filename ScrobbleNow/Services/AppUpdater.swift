import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    @Published private(set) var canCheckForUpdates = false
    @Published var updateAvailable = false
    private var controller: SPUStandardUpdaterController?
    private let userDriverDelegate = UpdateReminderDelegate()

    /// Sparkle refuses updates that are not signed with the key in SUPublicEDKey, so without one there is nothing to run.
    nonisolated static func isConfigured(publicKey: String?) -> Bool {
        !(publicKey ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isConfigured: Bool {
        Self.isConfigured(publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
    }

    func start() {
        guard controller == nil, isConfigured else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: userDriverDelegate
        )
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        self.controller = controller
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

/// A menu-bar app has no Dock icon, and Sparkle's scheduled alerts open behind other windows, so a found
/// update is flagged on the menu bar icon until the user looks at it.
final class UpdateReminderDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        Task { @MainActor in AppUpdater.shared.updateAvailable = true }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in AppUpdater.shared.updateAvailable = false }
    }

    func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in AppUpdater.shared.updateAvailable = false }
    }
}
