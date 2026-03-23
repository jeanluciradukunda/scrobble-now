import SwiftUI

struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()
    let onAlbumTap: (String, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if vm.isLoading && vm.dayGroups.isEmpty {
                Spacer()
                ProgressView().scaleEffect(0.8)
                Text("Loading history...")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.dayGroups) { day in
                            daySection(day)
                        }
                    }
                }
            }
        }
        .task { await vm.load() }
    }

    private func daySection(_ day: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            HStack(spacing: 6) {
                Text(day.displayDate)
                    .font(.system(size: 10, weight: .bold))
                Spacer()
                HStack(spacing: 8) {
                    statPill("\(day.totalScrobbles)", icon: "music.note")
                    statPill("\(day.uniqueArtists)", icon: "person")
                    statPill("\(day.uniqueAlbums)", icon: "square.stack")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.02))

            // Tracks
            ForEach(day.tracks) { track in
                HStack(spacing: 8) {
                    // Time
                    Text(timeString(track.timestamp))
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .frame(width: 32, alignment: .trailing)

                    // Timeline dot
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
                        Circle()
                            .fill(track.loved ? Color.red : AppAccent.current.opacity(0.4))
                            .frame(width: 5, height: 5)
                        Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
                    }
                    .frame(width: 5)

                    // Small artwork
                    AsyncImage(url: track.albumArtworkURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(1, contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.1)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.name)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                        Text(track.artistName)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if track.loved {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !track.albumName.isEmpty else { return }
                    onAlbumTap(track.albumName, track.artistName)
                }
            }
        }
    }

    private func statPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 6))
            Text(text)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.tertiary)
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
}
