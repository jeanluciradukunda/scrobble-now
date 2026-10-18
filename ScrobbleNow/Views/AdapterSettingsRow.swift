#if os(macOS)
import SwiftUI

struct AdapterSettingsRow: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var bridge = MediaRemoteBridge.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Detect any player (experimental)").font(.system(size: 10))
                Spacer()
                Toggle("", isOn: $settings.useMediaRemoteAdapter)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            Text("Reads what macOS shows as Now Playing, for players beyond Spotify, Music and browser tabs.")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                Circle().fill(statusColour).frame(width: 5, height: 5)
                Text(statusText).font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch bridge.adapterStatus {
        case .off: return "Off"
        case .starting: return "Starting"
        case .running: return "Running"
        case .unavailable: return "Unavailable on this Mac"
        }
    }

    private var statusColour: Color {
        switch bridge.adapterStatus {
        case .off: return .secondary
        case .starting: return .orange
        case .running: return .green
        case .unavailable: return .red
        }
    }
}
#endif
