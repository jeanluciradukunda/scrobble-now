import SwiftUI

struct AlbumDetailView: View {
    let albumName: String
    let artistName: String
    @State private var albums: [AlbumDetail] = []
    @State private var selectedIndex: Int = 0
    @State private var artworkIndex: Int = 0
    @State private var isLoading = true
    @State private var error: String?

    private let discoveryService = AlbumDiscoveryService()

    private var currentAlbum: AlbumDetail? {
        guard selectedIndex < albums.count else { return nil }
        return albums[selectedIndex]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Back / title
                HStack {
                    Text(artistName.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppAccent.current)
                    Spacer()
                    if albums.count > 1 {
                        Text("\(selectedIndex + 1)/\(albums.count) sources")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(.horizontal, 16)

                if isLoading {
                    Spacer().frame(height: 60)
                    ProgressView().scaleEffect(0.8)
                    Text("Searching 5 sources...")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Spacer()
                } else if let error = error {
                    Spacer().frame(height: 60)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Spacer()
                } else if let album = currentAlbum {
                    // Artwork
                    artworkView(album: album)
                        .padding(.horizontal, 16)

                    // Album info
                    albumInfoView(album: album)
                        .padding(.horizontal, 16)

                    // Source badge
                    sourceBadge(album: album)
                        .padding(.horizontal, 16)

                    // Tags
                    if !album.tags.isEmpty {
                        tagsView(tags: album.tags)
                            .padding(.horizontal, 16)
                    }

                    // Track listing
                    if !album.tracks.isEmpty {
                        trackListView(tracks: album.tracks)
                    }

                    // External links
                    externalLinks(album: album)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    // Source switcher
                    if albums.count > 1 {
                        sourceSwitcher
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(.top, 8)
        }
        .task {
            await loadAlbum()
        }
    }

    // MARK: - Load

    private func loadAlbum() async {
        isLoading = true
        error = nil
        do {
            let results = try await discoveryService.discover(albumName: albumName, artistName: artistName)
            if results.isEmpty {
                error = "No album found across 5 sources"
            } else {
                albums = results
                selectedIndex = 0
                artworkIndex = 0
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Artwork

    private func artworkView(album: AlbumDetail) -> some View {
        VStack(spacing: 6) {
            let urls = album.allArtworkURLs
            let safeIdx = urls.isEmpty ? 0 : min(artworkIndex, urls.count - 1)

            if !urls.isEmpty {
                AsyncImage(url: urls[safeIdx]) { phase in
                    if case .success(let img) = phase {
                        img.resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(width: 240, height: 240)
                            .clipped()
                    } else if case .failure = phase {
                        artworkPlaceholder
                    } else {
                        artworkPlaceholder
                            .overlay { ProgressView().scaleEffect(0.7) }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width < -20, artworkIndex < urls.count - 1 {
                                withAnimation { artworkIndex += 1 }
                            } else if value.translation.width > 20, artworkIndex > 0 {
                                withAnimation { artworkIndex -= 1 }
                            }
                        }
                )

                if urls.count > 1 {
                    HStack(spacing: 3) {
                        ForEach(0..<urls.count, id: \.self) { i in
                            Circle()
                                .fill(i == safeIdx ? AppAccent.current : Color.white.opacity(0.15))
                                .frame(width: i == safeIdx ? 5 : 3, height: i == safeIdx ? 5 : 3)
                        }
                    }
                    Text("\(safeIdx + 1)/\(urls.count) covers")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            } else {
                artworkPlaceholder
            }
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .frame(width: 240, height: 240)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No artwork")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }
            }
    }

    // MARK: - Album Info

    private func albumInfoView(album: AlbumDetail) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(album.albumName)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(2)

            Text(album.artistName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                if let year = album.releaseYear {
                    Text(String(year))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                if !album.tracks.isEmpty {
                    Text("\(album.tracks.count) tracks")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                if let listeners = album.listeners, listeners > 0 {
                    Text("\(formatNumber(listeners)) listeners")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Source Badge

    private func sourceBadge(album: AlbumDetail) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                Circle()
                    .fill(album.confidenceScore >= 60 ? .green : album.confidenceScore >= 40 ? .orange : .red)
                    .frame(width: 5, height: 5)
                Text("via \(album.source.label)")
                    .font(.system(size: 8, weight: .medium))
                Text("\(Int(album.confidenceScore))%")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppAccent.current)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()
        }
    }

    // MARK: - Tags

    private func tagsView(tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tags.prefix(8), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.05), in: Capsule())
                        .overlay { Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5) }
                }
            }
        }
    }

    // MARK: - Track List

    private func trackListView(tracks: [AlbumTrack]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRACKLIST")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.tertiary)
                Spacer()
                let totalMs = tracks.reduce(0) { $0 + $1.durationMs }
                if totalMs > 0 {
                    Text(formatDuration(totalMs))
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            ForEach(tracks) { track in
                HStack(spacing: 6) {
                    Text(String(format: "%02d", track.trackNumber))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .frame(width: 16)

                    Text(track.name)
                        .font(.system(size: 10))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let pc = track.userPlaycount, pc > 0 {
                        Text("\(pc)×")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(AppAccent.current)
                    }

                    if track.durationMs > 0 {
                        Text(track.durationFormatted)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 3)
                .background(track.trackNumber % 2 == 0 ? Color.white.opacity(0.02) : Color.clear)
            }
        }
    }

    // MARK: - External Links

    private func externalLinks(album: AlbumDetail) -> some View {
        let bandcampQuery = "\(album.artistName) \(album.albumName)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bandcampURL = URL(string: "https://bandcamp.com/search?q=\(bandcampQuery)")

        return HStack(spacing: 4) {
            if let url = album.lastfmURL {
                linkButton(label: "Last.fm", color: Color(red: 0.84, green: 0.06, blue: 0.03), url: url)
            }
            if let url = album.musicbrainzURL {
                linkButton(label: "MusicBrainz", color: .orange, url: url)
            }
            if let url = album.discogsURL {
                linkButton(label: "Discogs", color: .teal, url: url)
            }
            if let url = album.appleMusicURL {
                linkButton(label: "Apple Music", color: .pink, url: url)
            }
            if let url = bandcampURL {
                linkButton(label: "Bandcamp", color: Color(red: 0.38, green: 0.73, blue: 0.73), url: url)
            }
        }
    }

    private func linkButton(label: String, color: Color, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(color.opacity(0.2), lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source Switcher

    private var sourceSwitcher: some View {
        VStack(spacing: 4) {
            Text("OTHER SOURCES")
                .font(.system(size: 7, weight: .bold))
                .tracking(1)
                .foregroundStyle(.quaternary)

            HStack(spacing: 4) {
                ForEach(Array(albums.enumerated()), id: \.offset) { i, album in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIndex = i
                            artworkIndex = 0
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(album.source.label)
                                .font(.system(size: 7, weight: .medium))
                            Text("\(Int(album.confidenceScore))%")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(i == selectedIndex ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            if i == selectedIndex {
                                RoundedRectangle(cornerRadius: 5).fill(AppAccent.current.opacity(0.6))
                            } else {
                                RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.04))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func formatDuration(_ ms: Int) -> String {
        let totalSec = ms / 1000
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }
}
