import SwiftUI

struct LibraryView: View {
    @StateObject private var vm = LibraryViewModel()
    let onAlbumTap: (String, String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Period selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(LibraryViewModel.periods, id: \.value) { period in
                        Button {
                            vm.selectedPeriod = period.value
                            Task { await vm.load() }
                        } label: {
                            Text(period.label)
                                .font(.system(size: 8, weight: vm.selectedPeriod == period.value ? .bold : .medium))
                                .foregroundStyle(vm.selectedPeriod == period.value ? .white : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
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
            }
            .padding(.horizontal, 16)

            // Mode toggle
            HStack(spacing: 0) {
                ForEach(LibraryViewModel.LibraryMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { vm.mode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(vm.mode == mode ? .primary : .tertiary)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(vm.mode == mode ? Color.white.opacity(0.06) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)

            // Content
            if vm.isLoading && vm.topAlbums.isEmpty {
                Spacer()
                ProgressView().scaleEffect(0.8)
                Text("Loading library...")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
            } else if vm.mode == .albums {
                albumGrid
            } else {
                artistList
            }
        }
        .task { await vm.load() }
    }

    // MARK: - Album Grid

    private var albumGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ], spacing: 6) {
                ForEach(vm.topAlbums) { album in
                    albumCell(album)
                        .onTapGesture {
                            onAlbumTap(album.albumName, album.artistName)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func albumCell(_ album: TopAlbumEntry) -> some View {
        VStack(spacing: 3) {
            AsyncImage(url: album.artworkURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    Color.gray.opacity(0.1)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(album.albumName)
                .font(.system(size: 7, weight: .medium))
                .lineLimit(1)

            Text("\(album.playcount)×")
                .font(.system(size: 6, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Artist List

    private var artistList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 1) {
                ForEach(Array(vm.topArtists.enumerated()), id: \.element.id) { i, artist in
                    HStack(spacing: 8) {
                        Text("\(i + 1)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.quaternary)
                            .frame(width: 18, alignment: .trailing)

                        AsyncImage(url: artist.imageURL) { phase in
                            if case .success(let img) = phase {
                                img.resizable().aspectRatio(1, contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.1)
                            }
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())

                        Text(artist.name)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        Text("\(artist.playcount) plays")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
