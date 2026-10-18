import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    @Published private(set) var canCheckForUpdates = false
    private var controller: SPUStandardUpdaterController?

    /// Sparkle refuses updates that are not signed with the key in SUPublicEDKey, so without one there is nothing to run.
    nonisolated static func isConfigured(publicKey: String?) -> Bool {
        !(publicKey ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isConfigured: Bool {
        Self.isConfigured(publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
    }

    func start() {
        guard controller == nil, isConfigured else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        self.controller = controller
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
