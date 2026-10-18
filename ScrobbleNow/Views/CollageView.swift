import SwiftUI

struct CollageView: View {
    @StateObject private var vm = CollageViewModel()
    #if os(iOS)
    @State private var collageShareImage: Image?
    @State private var showShareSheet = false
    #endif

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

            // Grid size slider
            HStack(spacing: 8) {
                Text("\(vm.gridDimension)×\(vm.gridDimension)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppAccent.current)
                    .frame(width: 38)
                    .contentTransition(.numericText(value: Double(vm.gridDimension)))
                    .animation(.snappy(duration: 0.15), value: vm.gridDimension)

                Slider(
                    value: Binding(
                        get: { Double(vm.gridDimension) },
                        set: { vm.gridDimension = Int($0) }
                    ),
                    in: 2...10,
                    step: 1
                )
                .frame(maxWidth: .infinity)
                #if os(iOS)
                .controlSize(.mini)
                #endif
                .accessibilityLabel("Grid size")
                .accessibilityValue("\(vm.gridDimension) by \(vm.gridDimension)")
                .sensoryFeedback(.selection, trigger: vm.gridDimension)

                Text("\(vm.gridDimension * vm.gridDimension)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .frame(width: 28, alignment: .trailing)
                    .contentTransition(.numericText(value: Double(vm.gridDimension * vm.gridDimension)))
                    .animation(.snappy(duration: 0.15), value: vm.gridDimension)
            }
            .padding(.horizontal, 16)

            // Period selector — pill buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(LibraryViewModel.periods, id: \.value) { period in
                        Button {
                            vm.period = period.value
                            Task { await vm.generate() }
                        } label: {
                            Text(period.label)
                                .font(.system(size: 9, weight: vm.period == period.value ? .bold : .medium))
                                .foregroundStyle(vm.period == period.value ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background {
                                    if vm.period == period.value {
                                        Capsule().fill(AppAccent.current.opacity(0.7))
                                    } else {
                                        Capsule().fill(Color.white.opacity(0.05))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(period.label)
                        .accessibilityAddTraits(vm.period == period.value ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            .sensoryFeedback(.selection, trigger: vm.period)

            // Toggles row
            HStack(spacing: 14) {
                Toggle("Titles", isOn: $vm.showTitles)
                Toggle("Hide no-cover", isOn: $vm.hideAlbumsWithoutCovers)
                Spacer()
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 9))
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppAccent.current)
                .padding(.top, 4)
                Spacer()
            } else {
                // The actual grid
                collageGrid
                    .padding(.horizontal, 8)

                // Export button
                HStack(spacing: 8) {
                    #if os(macOS)
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
                    #else
                    Button {
                        if let data = vm.shareCollage(), let image = UIImage(data: data) {
                            collageShareImage = Image(uiImage: image)
                            showShareSheet = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 9))
                            Text("Share")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(AppAccent.current)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppAccent.current.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    #endif

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
            }

            Spacer(minLength: 4)
        }
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            if let image = collageShareImage {
                ShareLink(item: image, preview: SharePreview("Scrobble Collage", image: image))
            }
        }
        #endif
        .sensoryFeedback(.impact(weight: .heavy), trigger: vm.albums.count) { old, new in
            new > 0 && old == 0
        }
        .sensoryFeedback(.success, trigger: vm.exportMessage) { _, new in new != nil }
    }

    // MARK: - Collage Grid

    private var collageGrid: some View {
        let cols = vm.gridSize.cols
        let albums = Array(vm.filteredAlbums.prefix(vm.gridSize.total))

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
