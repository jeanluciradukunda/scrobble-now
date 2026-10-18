import Foundation
#if os(iOS)
import Photos
import UIKit
#endif

enum ArtworkSaver {
    static func fileNames(count: Int, named name: String) -> [String] {
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        guard count > 1 else { return ["\(safe).jpg"] }
        return (1...count).map { "\(safe) - \($0).jpg" }
    }

    /// Returns how many files were actually written.
    static func save(_ images: [Data], named name: String, in folder: URL) -> Int {
        zip(images, fileNames(count: images.count, named: name)).reduce(0) { saved, item in
            do {
                try item.0.write(to: folder.appendingPathComponent(item.1), options: .atomic)
                return saved + 1
            } catch {
                return saved
            }
        }
    }

    #if os(iOS)
    static func saveToPhotos(_ images: [Data]) async -> String {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return "Photos access denied" }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for data in images {
                    if let image = UIImage(data: data) { PHAssetChangeRequest.creationRequestForAsset(from: image) }
                }
            }
            return images.count == 1 ? "Saved to Photos" : "Saved \(images.count) covers to Photos"
        } catch {
            return "Save failed"
        }
    }
    #endif
}
