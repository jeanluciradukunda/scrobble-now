import SwiftUI

private struct AlbumRef: Identifiable {
    let id = UUID()
    let name: String
    let artist: String
}

struct LibraryView: View {
    @StateObject private var vm = LibraryViewModel()
    let onAlbumTap: (String, String) -> Void

    #if os(iOS)
    @State private var albumSheet: AlbumRef?
    #endif

    // MARK: Platform sizing
    #if os(iOS)
    private let gridColumns   = 2
    private let albumFontSz:  CGFloat = 13
    private let albumSubSz:   CGFloat = 11
    private let rowImgSz:     CGFloat = 48
    private let rowFontSz:    CGFloat = 15
    private let rowSubFontSz: CGFloat = 12
    private let numFontSz:    CGFloat = 12
    private let ctrlFontSz:   CGFloat = 14
    private let artCorner:    CGFloat = 10
    private let rowVPad:      CGFloat = 10
    #else
    private let gridColumns   = 3
    private let albumFontSz:  CGFloat = 7
    private let albumSubSz:   CGFloat = 6
    private let rowImgSz:     CGFloat = 28
    private let rowFontSz:    CGFloat = 10
    private let rowSubFontSz: CGFloat = 8
    private let numFontSz:    CGFloat = 8
    private let ctrlFontSz:   CGFloat = 9
    private let artCorner:    CGFloat = 6
    private let rowVPad:      CGFloat = 4
    #endif

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider().opacity(0.1)
            content
        }
        .task { await vm.load() }
        #if os(iOS)
        .sheet(item: $albumSheet) { ref in
            NavigationStack {
                AlbumDetailView(albumName: ref.name, artistName: ref.artist)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { albumSheet = nil }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        #endif
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 6) {
            // Mode toggle
            HStack(spacing: 0) {
                ForEach(LibraryViewModel.LibraryMode.allCases, id: \.self) { m in
                    Button {
                        withAnimation(.smooth(duration: 0.18)) { vm.mode = m }
                    } label: {
                        Text(m.rawValue)
                            .font(.system(size: ctrlFontSz, weight: .semibold))
                            .foregroundStyle(vm.mode == m ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(vm.mode == m ? AppAccent.current.opacity(0.85) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.06), in: Capsule())
            .padding(.horizontal, 16)
            .sensoryFeedback(.selection, trigger: vm.mode)

            // Period selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(LibraryViewModel.periods, id: \.value) { period in
                        Button {
                            vm.selectedPeriod = period.value
                            Task { await vm.load() }
                        } label: {
                            Text(period.label)
                                .font(.system(size: ctrlFontSz - 2, weight: vm.selectedPeriod == period.value ? .bold : .medium))
                                .foregroundStyle(vm.selectedPeriod == period.value ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background {
                                    if vm.selectedPeriod == period.value {
                                        Capsule().fill(AppAccent.current.opacity(0.7))
                                    } else {
                                        Capsule().fill(Color.white.opacity(0.05))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.topAlbums.isEmpty && vm.topArtists.isEmpty && vm.topTracks.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                ProgressView().scaleEffect(0.9)
                Text("Loading library…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            Group {
                switch vm.mode {
                case .albums:  albumGrid
                case .artists: artistList
                case .tracks:  trackList
                }
            }
            .animation(.smooth(duration: 0.2), value: vm.mode)
        }
    }

    // MARK: - Album Grid

    private var albumGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: gridColumns),
                spacing: 12
            ) {
                ForEach(vm.topAlbums) { album in
                    albumCell(album)
                        .onTapGesture { handleAlbumTap(album.albumName, album.artistName) }
                        .contextMenu {
                            Button {
                                handleAlbumTap(album.albumName, album.artistName)
                            } label: {
                                Label("View Album", systemImage: "square.stack")
                            }
                            if let url = album.lastfmURL {
                                Button { openURL(url) } label: {
                                    Label("Open on Last.fm", systemImage: "safari")
                                }
                            }
                            Divider()
                            Button {
                                copyToClipboard("\(album.artistName) — \(album.albumName)")
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        .accessibilityLabel("\(album.albumName) by \(album.artistName), \(album.playcount) plays")
                        .accessibilityHint("Double-tap to view album")
                        .scrollTransition(.interactive) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.4)
                                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func albumCell(_ album: TopAlbumEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            AsyncImage(url: album.artworkURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    Color.gray.opacity(0.1)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 18))
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: artCorner))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

            Text(album.albumName)
                .font(.system(size: albumFontSz, weight: .semibold))
                .lineLimit(1)

            HStack {
                Text(album.artistName)
                    .font(.system(size: albumSubSz))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(album.playcount)×")
                    .font(.system(size: albumSubSz, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Artist List

    private var artistList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                let max = vm.topArtists.first?.playcount ?? 1
                ForEach(Array(vm.topArtists.enumerated()), id: \.element.id) { i, artist in
                    artistRow(rank: i + 1, artist: artist, maxPlays: max)
                        .scrollTransition(.interactive) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.45)
                                .offset(x: phase.value * 8)
                        }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func artistRow(rank: Int, artist: TopArtistEntry, maxPlays: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: numFontSz, design: .monospaced))
                .foregroundStyle(.quaternary)
                .frame(width: 22, alignment: .trailing)

            AsyncImage(url: artist.imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    Circle().fill(Color.gray.opacity(0.12))
                        .overlay {
                            Image(systemName: "person")
                                .font(.system(size: rowImgSz * 0.38))
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: rowImgSz, height: rowImgSz)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.system(size: rowFontSz, weight: .semibold))
                    .lineLimit(1)

                GeometryReader { geo in
                    let barWidth = maxPlays > 0
                        ? CGFloat(artist.playcount) / CGFloat(maxPlays) * geo.size.width
                        : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06)).frame(height: 3)
                        Capsule().fill(AppAccent.current.opacity(0.5)).frame(width: barWidth, height: 3)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            Text("\(artist.playcount)")
                .font(.system(size: rowSubFontSz, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowVPad)
        .contextMenu {
            if let url = artist.lastfmURL {
                Button { openURL(url) } label: {
                    Label("Open on Last.fm", systemImage: "safari")
                }
            }
            Button {
                copyToClipboard(artist.name)
            } label: {
                Label("Copy Name", systemImage: "doc.on.doc")
            }
        }
        .accessibilityLabel("\(artist.name), \(artist.playcount) plays, ranked \(rank)")
    }

    // MARK: - Track List

    private var trackList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.topTracks.enumerated()), id: \.element.id) { i, track in
                    topTrackRow(rank: i + 1, track: track)
                        .scrollTransition(.interactive) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.45)
                                .offset(x: phase.value * 8)
                        }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func topTrackRow(rank: Int, track: TopTrackEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: numFontSz, design: .monospaced))
                .foregroundStyle(.quaternary)
                .frame(width: 22, alignment: .trailing)

            AsyncImage(url: track.imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: artCorner * 0.7)
                        .fill(Color.gray.opacity(0.12))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: rowImgSz * 0.3))
                                .foregroundStyle(.quaternary)
                        }
                }
            }
            .frame(width: rowImgSz, height: rowImgSz)
            .clipShape(RoundedRectangle(cornerRadius: artCorner * 0.7))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.system(size: rowFontSz, weight: .semibold))
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.system(size: rowSubFontSz))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(track.playcount)×")
                .font(.system(size: rowSubFontSz, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowVPad)
        .contextMenu {
            if let url = track.lastfmURL {
                Button { openURL(url) } label: {
                    Label("Open on Last.fm", systemImage: "safari")
                }
            }
            Button {
                copyToClipboard("\(track.artistName) — \(track.name)")
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        .accessibilityLabel("\(track.name) by \(track.artistName), \(track.playcount) plays, ranked \(rank)")
    }

    // MARK: - Tap

    private func handleAlbumTap(_ album: String, _ artist: String) {
        onAlbumTap(album, artist)
        #if os(iOS)
        albumSheet = AlbumRef(name: album, artist: artist)
        #endif
    }

    // MARK: - URL / Clipboard

    private func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
