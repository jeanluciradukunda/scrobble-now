import SwiftUI

struct UpdatesSection: View {
    @ObservedObject private var updater = AppUpdater.shared

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        HStack {
            Text("Version \(version)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Spacer()
            if updater.isConfigured {
                Button("Check for Updates…", action: updater.checkForUpdates)
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppAccent.current)
                    .disabled(!updater.canCheckForUpdates)
            } else {
                Text("Updates not configured in this build")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
