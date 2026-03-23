import SwiftUI

struct CollageView: View {
    @StateObject private var vm = CollageViewModel()

    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                Text("COLLAGE")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.tertiary)
                Spacer()
                if vm.isLoading {
                    ProgressView().scaleEffect(0.5)
                }
            }
            .padding(.horizontal, 16)

            // Grid size selector
            HStack(spacing: 4) {
                ForEach(CollageViewModel.gridSizes, id: \.label) { size in
                    Button {
                        vm.gridSize = size
                        Task { await vm.generate() }
                    } label: {
                        Text(size.label)
                            .font(.system(size: 8, weight: vm.gridSize.label == size.label ? .bold : .medium))
                            .foregroundStyle(vm.gridSize.label == size.label ? .white : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background {
                                if vm.gridSize.label == size.label {
                                    Capsule().fill(AppAccent.current.opacity(0.7))
                                } else {
                                    Capsule().fill(Color.white.opacity(0.05))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Period
                Menu {
                    ForEach(LibraryViewModel.periods, id: \.value) { period in
                        Button(period.label) {
                            vm.period = period.value
                            Task { await vm.generate() }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(vm.periodLabel)
                            .font(.system(size: 8, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 6))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.05), in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 16)

            // Collage grid
            if vm.albums.isEmpty && !vm.isLoading {
                Spacer()
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("Generate a collage from your listening")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Button("Generate") {
                    Task { await vm.generate() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppAccent.current)
                .padding(.top, 4)
                Spacer()
            } else {
                // The actual grid
                collageGrid
                    .padding(.horizontal, 8)

                // Export button
                HStack(spacing: 8) {
                    Button {
                        vm.exportCollage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 9))
                            Text("Save Image")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(AppAccent.current)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppAccent.current.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.copyToClipboard()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                            Text("Copy")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    if vm.exportMessage != nil {
                        Text(vm.exportMessage!)
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                // Show titles toggle
                Toggle("Show titles", isOn: $vm.showTitles)
                    .font(.system(size: 9))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 4)
        }
    }

    // MARK: - Collage Grid

    private var collageGrid: some View {
        let cols = vm.gridSize.cols
        let albums = Array(vm.albums.prefix(vm.gridSize.total))

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: cols), spacing: 2) {
            ForEach(Array(albums.enumerated()), id: \.element.id) { _, album in
                ZStack(alignment: .bottom) {
                    AsyncImage(url: album.artworkURL) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(1, contentMode: .fill)
                        } else {
                            Color(white: 0.1)
                                .overlay {
                                    Text(album.albumName.prefix(2).uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)

                    if vm.showTitles {
                        VStack(spacing: 0) {
                            Text(album.albumName)
                                .font(.system(size: 5, weight: .bold))
                                .lineLimit(1)
                            Text(album.artistName)
                                .font(.system(size: 4))
                                .lineLimit(1)
                                .opacity(0.8)
                        }
                        .foregroundStyle(.white)
                        .padding(2)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.6))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
    }
}
