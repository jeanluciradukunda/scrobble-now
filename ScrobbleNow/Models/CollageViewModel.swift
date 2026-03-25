import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct GridSize: Equatable {
    let label: String
    let cols: Int
    let rows: Int
    var total: Int { cols * rows }

    static func == (lhs: GridSize, rhs: GridSize) -> Bool { lhs.label == rhs.label }
}

@MainActor
class CollageViewModel: ObservableObject {
    @Published var albums: [TopAlbumEntry] = []
    @Published var isLoading = false
    @Published var gridSize: GridSize = GridSize(label: "3×3", cols: 3, rows: 3)
    @Published var period: String = "7day"
    @Published var showTitles: Bool = true
    @Published var exportMessage: String?

    /// Pre-downloaded artwork keyed by URL string
    private var downloadedImages: [String: PlatformImage] = [:]

    static let gridSizes: [GridSize] = [
        GridSize(label: "3×3", cols: 3, rows: 3),
        GridSize(label: "4×4", cols: 4, rows: 4),
        GridSize(label: "5×5", cols: 5, rows: 5),
        GridSize(label: "10×10", cols: 10, rows: 10),
    ]

    var periodLabel: String {
        LibraryViewModel.periods.first(where: { $0.value == period })?.label ?? period
    }

    private let lastfm = LastFMService()

    func generate() async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else { return }

        isLoading = true
        do {
            albums = try await lastfm.getTopAlbums(user: username, period: period, limit: gridSize.total)
            // Pre-download all artwork so export doesn't block
            await predownloadArtwork()
        } catch {
            print("Collage generation failed: \(error)")
        }
        isLoading = false
    }

    private func predownloadArtwork() async {
        await withTaskGroup(of: (String, PlatformImage?).self) { group in
            for album in albums.prefix(gridSize.total) {
                guard let url = album.artworkURL else { continue }
                let key = url.absoluteString
                if downloadedImages[key] != nil { continue }

                group.addTask {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return (key, PlatformImage(data: data))
                    } catch {
                        return (key, nil)
                    }
                }
            }

            for await (key, image) in group {
                if let image { downloadedImages[key] = image }
            }
        }
    }

    // MARK: - Export as Image

    #if os(macOS)
    func exportCollage() {
        guard let pngData = renderCollagePNG() else {
            exportMessage = "Render failed"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "scrobble-collage-\(gridSize.label)-\(period).png"
        panel.canCreateDirectories = true
        panel.level = .floating

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            try? pngData.write(to: url)
            Task { @MainActor [weak self] in
                self?.exportMessage = "Saved!"
                try? await Task.sleep(for: .seconds(2))
                self?.exportMessage = nil
            }
        }
    }

    func copyToClipboard() {
        guard let pngData = renderCollagePNG() else {
            exportMessage = "Render failed"
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(pngData, forType: .png)
        exportMessage = "Copied!"
        Task {
            try? await Task.sleep(for: .seconds(2))
            exportMessage = nil
        }
    }
    #endif

    #if os(iOS)
    func shareCollage() -> Data? {
        return renderCollagePNG()
    }

    func copyToClipboard() {
        guard let pngData = renderCollagePNG(),
              let image = UIImage(data: pngData) else {
            exportMessage = "Render failed"
            return
        }

        UIPasteboard.general.image = image
        exportMessage = "Copied!"
        Task {
            try? await Task.sleep(for: .seconds(2))
            exportMessage = nil
        }
    }
    #endif

    // MARK: - Render to PNG Data

    private func renderCollagePNG() -> Data? {
        let cellSize = 300
        let cols = gridSize.cols
        let rows = min(gridSize.rows, (albums.count + cols - 1) / cols)
        let width = cols * cellSize
        let height = rows * cellSize

        guard width > 0, height > 0 else { return nil }

        #if os(macOS)
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )
        guard let bitmap else { return nil }

        let ctx = NSGraphicsContext(bitmapImageRep: bitmap)
        guard let ctx else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        // Black background
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        let subset = Array(albums.prefix(gridSize.total))
        for (i, album) in subset.enumerated() {
            let col = i % cols
            let row = i / cols
            let x = col * cellSize
            let y = height - (row + 1) * cellSize // flip Y

            let rect = NSRect(x: x, y: y, width: cellSize, height: cellSize)

            // Use pre-downloaded image
            if let artURL = album.artworkURL,
               let albumImage = downloadedImages[artURL.absoluteString] {
                albumImage.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
            } else {
                NSColor(white: 0.1, alpha: 1).setFill()
                rect.fill()

                // Draw initials
                let initials = String(album.albumName.prefix(2)).uppercased()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 24),
                    .foregroundColor: NSColor(white: 0.3, alpha: 1),
                ]
                let str = NSAttributedString(string: initials, attributes: attrs)
                let strSize = str.size()
                str.draw(at: NSPoint(x: CGFloat(x) + (CGFloat(cellSize) - strSize.width) / 2,
                                     y: CGFloat(y) + (CGFloat(cellSize) - strSize.height) / 2))
            }

            // Title overlay
            if showTitles {
                let barHeight: CGFloat = 36
                let barRect = NSRect(x: x, y: y, width: cellSize, height: Int(barHeight))
                NSColor(white: 0, alpha: 0.65).setFill()
                barRect.fill()

                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: NSColor.white,
                ]
                let artistAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor(white: 1, alpha: 0.8),
                ]

                NSAttributedString(string: album.albumName, attributes: titleAttr)
                    .draw(at: NSPoint(x: CGFloat(x) + 6, y: CGFloat(y) + 16))
                NSAttributedString(string: album.artistName, attributes: artistAttr)
                    .draw(at: NSPoint(x: CGFloat(x) + 6, y: CGFloat(y) + 2))
            }
        }

        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [.compressionFactor: 0.9])

        #elseif os(iOS)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            // Black background
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            let subset = Array(albums.prefix(gridSize.total))
            for (i, album) in subset.enumerated() {
                let col = i % cols
                let row = i / cols
                let x = col * cellSize
                let y = row * cellSize

                let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)

                // Use pre-downloaded image
                if let artURL = album.artworkURL,
                   let albumImage = downloadedImages[artURL.absoluteString] {
                    albumImage.draw(in: rect)
                } else {
                    UIColor(white: 0.1, alpha: 1).setFill()
                    ctx.fill(rect)

                    // Draw initials
                    let initials = String(album.albumName.prefix(2)).uppercased()
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor(white: 0.3, alpha: 1),
                    ]
                    let str = NSAttributedString(string: initials, attributes: attrs)
                    let strSize = str.size()
                    str.draw(at: CGPoint(x: CGFloat(x) + (CGFloat(cellSize) - strSize.width) / 2,
                                         y: CGFloat(y) + (CGFloat(cellSize) - strSize.height) / 2))
                }

                // Title overlay
                if showTitles {
                    let barHeight: CGFloat = 36
                    let barRect = CGRect(x: x, y: y + cellSize - Int(barHeight), width: cellSize, height: Int(barHeight))
                    UIColor(white: 0, alpha: 0.65).setFill()
                    ctx.fill(barRect)

                    let titleAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                        .foregroundColor: UIColor.white,
                    ]
                    let artistAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor(white: 1, alpha: 0.8),
                    ]

                    NSAttributedString(string: album.albumName, attributes: titleAttr)
                        .draw(at: CGPoint(x: CGFloat(x) + 6, y: CGFloat(y + cellSize) - barHeight + 4))
                    NSAttributedString(string: album.artistName, attributes: artistAttr)
                        .draw(at: CGPoint(x: CGFloat(x) + 6, y: CGFloat(y + cellSize) - barHeight + 20))
                }
            }
        }

        return image.pngData()
        #endif
    }
}
