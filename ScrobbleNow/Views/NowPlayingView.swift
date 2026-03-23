import SwiftUI

enum AppMode: String {
    case feed, library, collage, history, stats, settings
}

struct NowPlayingView: View {
    @ObservedObject var viewModel: NowPlayingViewModel
    @ObservedObject var settings: SettingsManager
    @State private var mode: AppMode = .feed
    @State private var albumToView: (name: String, artist: String)?

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
                    Text(viewModel.nowPlaying != nil ? "LISTENING NOW" : "RECENT")
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

                if viewModel.isLoading && viewModel.recentTracks.isEmpty {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading scrobbles...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    Spacer()
                } else if let error = viewModel.errorMessage, viewModel.recentTracks.isEmpty {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    Spacer()
                } else {
                    // Now playing card
                    if let np = viewModel.nowPlaying {
                        nowPlayingCard(track: np)
                            .padding(.horizontal, 16)
                            .onTapGesture {
                                guard !np.albumName.isEmpty else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    albumToView = (np.albumName, np.artistName)
                                }
                            }
                    }

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

    // MARK: - Now Playing Card

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
