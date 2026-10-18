import Foundation

actor CacheService {
    static let shared = CacheService()

    private var albumCache: [String: AlbumDetail] = [:]

    // MARK: - Albums
    func getCachedAlbum(key: String) -> AlbumDetail? {
        albumCache[key.lowercased()]
    }

    func cacheAlbum(key: String, album: AlbumDetail) {
        albumCache[key.lowercased()] = album
    }
}
