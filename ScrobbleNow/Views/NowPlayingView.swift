import SwiftUI

enum AppMode: String {
    case feed, library, collage, history, stats, settings
}

struct NowPlayingView: View {
    @ObservedObject var viewModel: NowPlayingViewModel
    @ObservedObject var settings: SettingsManager
    @ObservedObject var scrobbler: SystemScrobbleService
    @State private var mode: AppMode = .feed
    @State private var albumToView: (name: String, artist: String)?
    @State private var isExpanded: Bool = false

    var body: some View {
        ZStack {
            VisualEffectBackground()

            VStack(spacing: 0) {
                // Top bar
                HStack(spacing: 8) {
                    // Library
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = mode == .library ? .feed : .library
                            albumToView = nil
                        }
                    } label: {
                        Image(systemName: "square.stack")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mode == .library ? AppAccent.current : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Library")

                    // Collage
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = mode == .collage ? .feed : .collage
                            albumToView = nil
                        }
                    } label: {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mode == .collage ? AppAccent.current : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Collage Generator")

                    // History
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = mode == .history ? .feed : .history
                            albumToView = nil
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mode == .history ? AppAccent.current : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Listening History")

                    // Stats
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = mode == .stats ? .feed : .stats
                            albumToView = nil
                        }
                    } label: {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mode == .stats ? AppAccent.current : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Statistics")

                    Spacer()

                    // Settings
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            mode = mode == .settings ? .feed : .settings
                            albumToView = nil
                        }
                    } label: {
                        Image(systemName: mode == .settings ? "xmark" : "gearshape")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mode == .settings ? AppAccent.current : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 2)

                if mode == .settings {
                    SettingsView(settings: settings, viewModel: viewModel)
                } else if mode == .library {
                    LibraryView { albumName, artistName in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            albumToView = (albumName, artistName)
                            mode = .feed
                        }
                    }
                } else if mode == .collage {
                    CollageView()
                } else if mode == .history {
                    HistoryView { albumName, artistName in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            albumToView = (albumName, artistName)
                            mode = .feed
                        }
                    }
                } else if mode == .stats {
                    StatisticsView()
                } else if let album = albumToView {
                    // Album detail view
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                albumToView = nil
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left").font(.system(size: 8, weight: .bold))
                                Text("Feed").font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(AppAccent.current)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppAccent.current.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)

                    AlbumDetailView(albumName: album.name, artistName: album.artist)
                } else {

                // Header
                VStack(spacing: 2) {
                    Text(scrobbler.currentTrack != nil ? "LISTENING NOW" : "RECENT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    Text("SCROBBLE NOW")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.primary)
                }
                .padding(.top, 4)
                .padding(.bottom, 8)

                // ALL active playing sources
                let playingSources = MediaRemoteBridge.shared.activeSources.values
                    .filter { $0.isPlaying }
                    .sorted { $0.timestamp > $1.timestamp }

                if let primary = playingSources.first {
                    if isExpanded {
                        // ═══════ EXPANDED: one source in focus ═══════
                        expandedNowPlaying(track: primary, allSources: Array(playingSources))
                    } else {
                        // ═══════ COMPACT: primary card ═══════
                        systemNowPlayingCard(track: primary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    isExpanded = true
                                }
                            }
                    }

                    // ═══════ OTHER SOURCES: horizontal ticker strip ═══════
                    if playingSources.count > 1 {
                        otherSourcesStrip(
                            sources: Array(playingSources.dropFirst()),
                            onSelect: { selected in
                                // Swap: make this the primary
                                MediaRemoteBridge.shared.currentTrack = selected
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isExpanded = true
                                }
                            }
                        )
                    }
                }

                if viewModel.isLoading && viewModel.recentTracks.isEmpty && scrobbler.currentTrack == nil {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading scrobbles...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    Spacer()
                } else {

                    // Recent tracks
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 1) {
                            ForEach(viewModel.recentTracks.filter { !$0.isNowPlaying }) { track in
                                trackRow(track: track)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        guard !track.albumName.isEmpty else { return }
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            albumToView = (track.albumName, track.artistName)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                // Footer
                HStack {
                    Text("\(viewModel.recentTracks.count) scrobbles")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                    Spacer()
                    Button {
                        Task { await viewModel.forceRefresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                } // end else (not settings mode)
            }
        }
    }

    // MARK: - Other Sources Horizontal Strip

    private func otherSourcesStrip(sources: [SystemNowPlaying], onSelect: @escaping (SystemNowPlaying) -> Void) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text("ALSO PLAYING")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.quaternary)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(sources.enumerated()), id: \.element.sourceBundleId) { _, source in
                        miniSourceCard(source: source)
                            .onTapGesture { onSelect(source) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 6)
    }

    private func miniSourceCard(source: SystemNowPlaying) -> some View {
        HStack(spacing: 6) {
            // Small artwork
            if let artwork = source.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.ultraThinMaterial)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(source.title)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    if let icon = MediaRemoteBridge.shared.appIcon(for: source.sourceBundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 8, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 1))
                    }
                    Text(source.artist)
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Expanded Now Playing (iOS Music-style)

    private func expandedNowPlaying(track: SystemNowPlaying, allSources: [SystemNowPlaying]) -> some View {
        VStack(spacing: 0) {
            // Collapse button
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 40, height: 20)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.bottom, 4)

            // Large album artwork
            Group {
                if let artwork = track.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: 240, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.bottom, 14)

            // Track title
            Text(track.title)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .padding(.horizontal, 20)

            // Artist
            Text(track.artist)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 2)
                .onTapGesture {
                    guard !track.album.isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        albumToView = (track.album, track.artist)
                        isExpanded = false
                    }
                }

            // Album (if available)
            if !track.album.isEmpty {
                Text(track.album)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.top, 1)
            }

            // Progress bar
            if track.duration > 0 {
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppAccent.current)
                                .frame(width: geo.size.width * track.progress)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(track.elapsedFormatted)
                        Spacer()
                        Text("-\(track.remainingFormatted)")
                    }
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
            }

            // Source + scrobble status
            HStack(spacing: 8) {
                // Source app
                HStack(spacing: 4) {
                    if let icon = MediaRemoteBridge.shared.appIcon(for: track.sourceBundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    Text(track.sourceAppName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Scrobble progress
                HStack(spacing: 4) {
                    if scrobbler.didScrobbleCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text("Scrobbled")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.green)
                    } else {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.08), lineWidth: 2)
                            Circle()
                                .trim(from: 0, to: scrobbler.scrobbleProgress)
                                .stroke(AppAccent.current, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 14, height: 14)
                        Text("\(Int(scrobbler.scrobbleProgress * 100))%")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // Action buttons
            HStack(spacing: 12) {
                expandedButton(icon: "heart", label: "Love") {
                    // TODO: Love track on Last.fm
                }
                expandedButton(icon: "magnifyingglass", label: "Discover") {
                    guard !track.artist.isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        albumToView = (track.album.isEmpty ? track.title : track.album, track.artist)
                        isExpanded = false
                    }
                }
                expandedButton(icon: "square.and.pencil", label: "Edit") {
                    // TODO: Edit metadata before scrobble
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)

            Spacer(minLength: 6)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func expandedButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 7, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - System Now Playing Card (from MediaRemote)

    private func systemNowPlayingCard(track: SystemNowPlaying) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // System artwork
                if let artwork = track.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.tertiary)
                        }
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Source app badge
                    HStack(spacing: 4) {
                        if let icon = MediaRemoteBridge.shared.appIcon(for: track.sourceBundleId) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 10, height: 10)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                        Text(track.sourceAppName.uppercased())
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Text(track.title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if !track.album.isEmpty {
                        Text(track.album)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Scrobble indicator
                VStack(spacing: 2) {
                    if scrobbler.didScrobbleCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    } else {
                        // Circular progress toward scrobble
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 2)
                            Circle()
                                .trim(from: 0, to: scrobbler.scrobbleProgress)
                                .stroke(AppAccent.current, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 18, height: 18)
                    }
                    Text(scrobbler.didScrobbleCurrent ? "✓" : "\(Int(scrobbler.scrobbleProgress * 100))%")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }

            // Progress bar
            if track.duration > 0 {
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(AppAccent.current.opacity(0.6))
                                .frame(width: geo.size.width * track.progress)
                        }
                    }
                    .frame(height: 3)

                    HStack {
                        Text(track.elapsedFormatted)
                        Spacer()
                        Text("-\(track.remainingFormatted)")
                    }
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.quaternary)
                }
                .padding(.top, 8)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppAccent.current.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AppAccent.current.opacity(0.15), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Last.fm Now Playing Card

    private func nowPlayingCard(track: ScrobbledTrack) -> some View {
        HStack(spacing: 10) {
            // Album art
            if let artwork = viewModel.albumArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Circle().fill(AppAccent.current).frame(width: 5, height: 5)
                    Text("NOW PLAYING")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppAccent.current)
                }

                Text(track.name)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !track.albumName.isEmpty {
                    Text(track.albumName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppAccent.current.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AppAccent.current.opacity(0.15), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Track Row

    private func trackRow(track: ScrobbledTrack) -> some View {
        HStack(spacing: 8) {
            // Small artwork
            AsyncImage(url: track.albumArtworkURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    Color.gray.opacity(0.1)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 1) {
                Text(track.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text(track.displayTime)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                if track.loved {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
