import SwiftUI

struct FailedScrobblesRow: View {
    @State private var failed: [ScrobbleCacheEntry] = []

    var body: some View {
        Group {
            if let latest = failed.first {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(failed.count == 1 ? "1 scrobble couldn't be sent to Last.fm"
                                               : "\(failed.count) scrobbles couldn't be sent to Last.fm")
                            .font(.system(size: 10, weight: .medium))
                        let line = "\(latest.artist.isEmpty ? "(no artist)" : latest.artist) - \(latest.track)"
                        Text("Latest: \(line)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .help(line)
                    }
                    Spacer()
                    Button("Clear") {
                        Task {
                            await ScrobbleCache.shared.clearFailed()
                            failed = []
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            }
        }
        .task { failed = await ScrobbleCache.shared.failedScrobbles() }
    }
}
