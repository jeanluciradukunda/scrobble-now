import Foundation

actor CacheService {
    static let shared = CacheService()

    private var albumCache: [String: AlbumDetail] = [:]
    private var imageCache: [URL: PlatformImage] = [:]
    private var recentTracksCache: [String: [ScrobbledTrack]] = [:]

    // MARK: - Albums
    func getCachedAlbum(key: String) -> AlbumDetail? {
        albumCache[key.lowercased()]
    }

    func cacheAlbum(key: String, album: AlbumDetail) {
        albumCache[key.lowercased()] = album
    }

    // MARK: - Images
    func getCachedImage(url: URL) -> PlatformImage? {
        imageCache[url]
    }

    func cacheImage(url: URL, image: PlatformImage) {
        imageCache[url] = image
        if imageCache.count > 100 {
            let keysToRemove = Array(imageCache.keys.prefix(20))
            for key in keysToRemove { imageCache.removeValue(forKey: key) }
        }
    }

    // MARK: - Recent Tracks
    func getCachedRecentTracks(user: String) -> [ScrobbledTrack]? {
        recentTracksCache[user.lowercased()]
    }

    func cacheRecentTracks(user: String, tracks: [ScrobbledTrack]) {
        recentTracksCache[user.lowercased()] = tracks
    }
}
