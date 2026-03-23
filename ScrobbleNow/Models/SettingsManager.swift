import SwiftUI
import ServiceManagement

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - General
    @AppStorage("showTitleInMenuBar") var showTitleInMenuBar: Bool = false
    @AppStorage("notifyNewTrack") var notifyNewTrack: Bool = true
    @AppStorage("pinMenuPopover") var pinMenuPopover: Bool = false

    // MARK: - Last.fm
    @AppStorage("lastfmUsername") var lastfmUsername: String = ""
    @AppStorage("pollIntervalSeconds") var pollIntervalSeconds: Double = 15

    // MARK: - Data
    @AppStorage("enableCaching") var enableCaching: Bool = true

    // MARK: - Appearance
    @AppStorage("accentColorName") var accentColorName: String = "red"

    // MARK: - Developer Mode
    @AppStorage("developerMode") var developerMode: Bool = false
    @AppStorage("scoreWeightTitle") var scoreWeightTitle: Double = 35
    @AppStorage("scoreWeightArtist") var scoreWeightArtist: Double = 30
    @AppStorage("scoreWeightTracks") var scoreWeightTracks: Double = 10
    @AppStorage("scoreWeightYear") var scoreWeightYear: Double = 5
    @AppStorage("scoreWeightSource") var scoreWeightSource: Double = 15
    @AppStorage("scoreWeightContent") var scoreWeightContent: Double = 5
    @AppStorage("scoreMinThreshold") var scoreMinThreshold: Double = 40

    // MARK: - System
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }
}
