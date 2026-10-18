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
    @State private var lastNowPlaying: ScrobbledTrack?
    @State private var showVisualizer = false
    @State private var visualizerTheme: VisualizerTheme = .bars
    @State private var showThemeLabel = false
    @Namespace private var artworkNS
    @Namespace private var albumZoomNS
    @State private var showScrollToTop = false
    @State private var feedScrollToTopToken = false

    #if os(macOS)
    private var bridge: MediaRemoteBridge { MediaRemoteBridge.shared }
    private var isShowingAlbumInline: Bool { albumToView != nil }
    #else
    private var bridge: MPNowPlayingBridge { MPNowPlayingBridge.shared }
    private var isShowingAlbumInline: Bool { false }
    #endif

    var body: some View {
        ZStack {
            #if os(macOS)
            VisualEffectBackground()
            #else
            Color(.systemBackground).ignoresSafeArea()
            #endif

            VStack(spacing: 0) {
                // Top bar
                HStack(spacing: 8) {
                    #if os(macOS)
                    // Library
                    navButton(icon: "square.stack", mode: .library, label: "Library")
                    // Collage
                    navButton(icon: "square.grid.3x3", mode: .collage, label: "Collage Generator")
                    // History
                    navButton(icon: "clock.arrow.circlepath", mode: .history, label: "Listening History")
                    // Stats
                    navButton(icon: "chart.bar", mode: .stats, label: "Statistics")
                    #endif

                    Spacer()

                    // Settings
                    Button {
                        withAnimation(.smooth(duration: 0.2)) {
                            mode = mode == .settings ? .feed : .settings
                            albumToView = nil
                        }
                    } label: {
                        Image(systemName: mode == .settings ? "xmark" : "gearshape")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mode == .settings ? AppAccent.current : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode == .settings ? "Close Settings" : "Settings")
                    #if os(macOS)
                    .help("Settings")
                    #endif
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 2)

                if mode == .settings {
                    SettingsView(settings: settings, viewModel: viewModel)
                } else if mode == .library {
                    LibraryView { albumName, artistName in
                        withAnimation(.smooth(duration: 0.2)) {
                            albumToView = (albumName, artistName)
                            mode = .feed
                        }
                    }
                } else if mode == .collage {
                    CollageView()
                } else if mode == .history {
                    HistoryView { albumName, artistName in
                        withAnimation(.smooth(duration: 0.2)) {
                            albumToView = (albumName, artistName)
                            mode = .feed
                        }
                    }
                } else if mode == .stats {
                    StatisticsView()
                } else if isShowingAlbumInline, let album = albumToView {
                    // Album detail view (macOS: inline; iOS: uses sheet below)
                    #if os(macOS)
                    HStack {
                        Button {
                            withAnimation(.smooth(duration: 0.2)) {
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
                    #endif
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
                let playingSources = bridge.activeSources.values
                    .filter { $0.isPlaying }
                    .sorted { $0.timestamp > $1.timestamp }

                if let primary = playingSources.first {
                    if isExpanded {
                        expandedNowPlaying(track: primary, allSources: Array(playingSources))
                    } else {
                        systemNowPlayingCard(track: primary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                            .onTapGesture {
                                withAnimation(.spring(duration: 0.45, bounce: 0.18)) {
                                    isExpanded = true
                                }
                            }
                    }

                    if playingSources.count > 1 {
                        otherSourcesStrip(
                            sources: Array(playingSources.dropFirst()),
                            onSelect: { selected in
                                bridge.currentTrack = selected
                                withAnimation(.spring(duration: 0.38, bounce: 0.12)) {
                                    isExpanded = true
                                }
                            }
                        )
                    }
                } else if let np = viewModel.nowPlaying ?? (isExpanded ? lastNowPlaying : nil) {
                    // Fallback: show Last.fm now-playing (cloud scrobble detection)
                    if isExpanded {
                        expandedLastFMNowPlaying(track: np)
                    } else {
                        nowPlayingCard(track: np)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                            .onTapGesture {
                                lastNowPlaying = np
                                withAnimation(.spring(duration: 0.45, bounce: 0.18)) {
                                    isExpanded = true
                                }
                            }
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
                        ScrollViewReader { proxy in
                            LazyVStack(spacing: 1) {
                                Color.clear.frame(height: 0).id("feedTop")
                                ForEach(viewModel.recentTracks.filter { !$0.isNowPlaying }) { track in
                                    trackRow(track: track)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            guard !track.albumName.isEmpty else { return }
                                            withAnimation(.smooth(duration: 0.2)) {
                                                albumToView = (track.albumName, track.artistName)
                                            }
                                        }
                                        .scrollTransition(.interactive) { content, phase in
                                            content
                                                .opacity(phase.isIdentity ? 1 : 0.5)
                                                .scaleEffect(phase.isIdentity ? 1 : 0.97)
                                        }
                                        .zoomSource(
                                            id: "\(track.albumName)-\(track.artistName)",
                                            in: albumZoomNS
                                        )
                                }
                            }
                            .onChange(of: feedScrollToTopToken) { _, _ in
                                withAnimation(.spring(duration: 0.5, bounce: 0.1)) {
                                    proxy.scrollTo("feedTop", anchor: .top)
                                }
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .onScrollThresholdChange(threshold: 80) { exceeded in
                        withAnimation(.smooth(duration: 0.2)) { showScrollToTop = exceeded }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if showScrollToTop {
                            Button {
                                feedScrollToTopToken.toggle()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(AppAccent.current)
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(10)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 8)
                }

                // Footer
                HStack {
                    Text("\(viewModel.recentTracks.count) scrobbles")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .contentTransition(.numericText(value: Double(viewModel.recentTracks.count)))
                    Spacer()
                    Button {
                        Task { await viewModel.forceRefresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .symbolEffect(.pulse, isActive: viewModel.isLoading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                } // end else (not settings mode)
            }
        }
        // MARK: iOS Album Detail Sheet
        #if os(iOS)
        .sheet(isPresented: Binding(
            get: { albumToView != nil },
            set: { if !$0 { withAnimation(.smooth(duration: 0.2)) { albumToView = nil } } }
        )) {
            if let album = albumToView {
                NavigationStack {
                    AlbumDetailView(albumName: album.name, artistName: album.artist)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    withAnimation(.smooth(duration: 0.2)) { albumToView = nil }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
                .zoomNavTransition(id: "\(album.name)-\(album.artist)", in: albumZoomNS)
            }
        }
        #endif
        // MARK: Haptics
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
        .sensoryFeedback(.selection, trigger: mode)
        .sensoryFeedback(.impact(weight: .medium), trigger: visualizerTheme)
        .sensoryFeedback(.success, trigger: scrobbler.didScrobbleCurrent) { _, new in new }
    }

    // MARK: - Nav Button Helper

    private func navButton(icon: String, mode targetMode: AppMode, label: String) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.2)) {
                mode = mode == targetMode ? .feed : targetMode
                albumToView = nil
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(mode == targetMode ? AppAccent.current : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        #if os(macOS)
        .help(label)
        #endif
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
                artwork.swiftUIImage
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
                    #if os(macOS)
                    if let icon = MediaRemoteBridge.shared.appIcon(for: source.sourceBundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 8, height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 1))
                    }
                    #endif
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

    // MARK: - Art / Visualizer Toggle Area

    @ViewBuilder
    private func artOrVisualizer<Art: View>(
        artwork: () -> Art,
        isPlaying: Bool
    ) -> some View {
        #if os(macOS)
        let frameSize: CGFloat = 240
        #else
        let frameSize: CGFloat = 300
        #endif

        ZStack(alignment: .topTrailing) {
            if showVisualizer {
                AudioVisualizerView(theme: visualizerTheme, isPlaying: isPlaying)
                    .frame(width: frameSize, height: frameSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Cycle theme on tap, return to art on double-tap
                Color.clear
                    .frame(width: frameSize, height: frameSize)
                    .onTapGesture(count: 2) {
                        withAnimation(.smooth(duration: 0.3)) { showVisualizer = false }
                    }
                    .onTapGesture {
                        visualizerTheme = visualizerTheme.next
                        withAnimation { showThemeLabel = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showThemeLabel = false }
                        }
                    }

                // Theme name label
                if showThemeLabel {
                    Text(visualizerTheme.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(10)
                        .transition(.opacity)
                }

                // Back-to-art button
                Button {
                    withAnimation(.smooth(duration: 0.3)) { showVisualizer = false }
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)

            } else {
                artwork()
                    .frame(width: frameSize, height: frameSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture {
                        withAnimation(.smooth(duration: 0.3)) { showVisualizer = true }
                        showThemeLabel = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showThemeLabel = false }
                        }
                    }

                // Visualizer hint badge on art
                Image(systemName: visualizerTheme.icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(6)
                    .background(.black.opacity(0.45), in: Circle())
                    .padding(10)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }

    // MARK: - Expanded Now Playing (iOS Music-style)

    private func expandedNowPlaying(track: SystemNowPlaying, allSources: [SystemNowPlaying]) -> some View {
        VStack(spacing: 0) {
            // Collapse button
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.45, bounce: 0.18)) {
                        isExpanded = false
                        showVisualizer = false
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

            // Album artwork / Visualizer toggle
            artOrVisualizer(
                artwork: { Group {
                    if let artwork = track.artwork {
                        artwork.swiftUIImage
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
                }},
                isPlaying: track.isPlaying
            )
            .matchedGeometryEffect(id: "sysArt", in: artworkNS)
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
                    withAnimation(.smooth(duration: 0.2)) {
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
                    #if os(macOS)
                    if let icon = MediaRemoteBridge.shared.appIcon(for: track.sourceBundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    #endif
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
                            .symbolEffect(.bounce.up, value: scrobbler.didScrobbleCurrent)
                            .transition(.blurReplace)
                        Text("Scrobbled")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.green)
                            .transition(.blurReplace)
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
                            .contentTransition(.numericText(value: scrobbler.scrobbleProgress))
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
                    withAnimation(.smooth(duration: 0.2)) {
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

    // MARK: - Expanded Last.fm Now Playing (cloud scrobble)

    private func expandedLastFMNowPlaying(track: ScrobbledTrack) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.45, bounce: 0.18)) {
                        isExpanded = false
                        lastNowPlaying = nil
                        showVisualizer = false
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

            // Album artwork / Visualizer toggle
            artOrVisualizer(
                artwork: { Group {
                    if let artURL = track.albumArtworkURL {
                        AsyncImage(url: artURL) { phase in
                            if case .success(let img) = phase {
                                img.resizable().aspectRatio(1, contentMode: .fill)
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
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }},
                isPlaying: true
            )
            .matchedGeometryEffect(id: "lastFMArt", in: artworkNS)
            .padding(.bottom, 14)

            Text(track.name)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .padding(.horizontal, 20)

            Text(track.artistName)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 2)

            if !track.albumName.isEmpty {
                Text(track.albumName)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.top, 1)
            }

            // Source badge
            HStack(spacing: 4) {
                PhaseAnimator([0.4, 1.0]) { opacity in
                    Circle().fill(AppAccent.current).frame(width: 5, height: 5)
                        .opacity(opacity)
                } animation: { _ in .easeInOut(duration: 0.9) }
                Text("SCROBBLING VIA LAST.FM")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppAccent.current)
            }
            .padding(.top, 10)

            // Action buttons
            HStack(spacing: 12) {
                expandedButton(icon: "heart", label: "Love") {
                    // TODO: Love track on Last.fm
                }
                expandedButton(icon: "magnifyingglass", label: "Discover") {
                    guard !track.artistName.isEmpty else { return }
                    withAnimation(.smooth(duration: 0.2)) {
                        albumToView = (track.albumName.isEmpty ? track.name : track.albumName, track.artistName)
                        isExpanded = false
                    }
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)

            Spacer(minLength: 6)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - System Now Playing Card (from MediaRemote)

    private func systemNowPlayingCard(track: SystemNowPlaying) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // System artwork
                Group {
                    if let artwork = track.artwork {
                        artwork.swiftUIImage
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
                }
                .matchedGeometryEffect(id: "sysArt", in: artworkNS)

                VStack(alignment: .leading, spacing: 3) {
                    // Source app badge
                    HStack(spacing: 4) {
                        #if os(macOS)
                        if let icon = MediaRemoteBridge.shared.appIcon(for: track.sourceBundleId) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 10, height: 10)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                        #endif
                        Text(track.sourceAppName.uppercased())
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        MiniEQView(color: AppAccent.current, isPlaying: track.isPlaying)
                            .frame(width: 12, height: 8)
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
                            .symbolEffect(.bounce.up, value: scrobbler.didScrobbleCurrent)
                            .transition(.blurReplace)
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
                        .transition(.blurReplace)
                    }
                    Text(scrobbler.didScrobbleCurrent ? "✓" : "\(Int(scrobbler.scrobbleProgress * 100))%")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText(value: scrobbler.scrobbleProgress))
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
            Group {
                if let artwork = viewModel.albumArtwork {
                    artwork.swiftUIImage
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
            }
            .matchedGeometryEffect(id: "lastFMArt", in: artworkNS)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    PhaseAnimator([0.4, 1.0]) { opacity in
                        Circle().fill(AppAccent.current).frame(width: 5, height: 5)
                            .opacity(opacity)
                    } animation: { _ in .easeInOut(duration: 0.7) }
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

#if os(macOS)
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
#endif

// MARK: - Platform-Availability Extensions

extension View {
    @ViewBuilder
    func zoomSource<ID: Hashable>(id: ID, in ns: Namespace.ID) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            self.matchedTransitionSource(id: id, in: ns)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomNavTransition<ID: Hashable>(id: ID, in ns: Namespace.ID) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: ns))
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func onScrollThresholdChange(threshold: CGFloat, action: @escaping (Bool) -> Void) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            self.onScrollGeometryChange(for: Bool.self, of: { $0.contentOffset.y > threshold }) { _, exceeded in
                action(exceeded)
            }
        } else {
            self
        }
    }
}
