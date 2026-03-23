import Foundation

actor iTunesService {

    func searchAlbum(album: String, artist: String) async throws -> [iTunesAlbum] {
        let queries = [
            "\(artist) \(album)",
            album
        ]

        for query in queries {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=album&limit=5")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let results = json?["results"] as? [[String: Any]], !results.isEmpty else { continue }

            return results.compactMap { dict -> iTunesAlbum? in
                guard let name = dict["collectionName"] as? String,
                      let artistName = dict["artistName"] as? String,
                      let collectionId = dict["collectionId"] as? Int else { return nil }

                let artworkStr = (dict["artworkUrl100"] as? String)?
                    .replacingOccurrences(of: "100x100", with: "600x600")
                let artworkURL = artworkStr.flatMap { URL(string: $0) }
                let year = (dict["releaseDate"] as? String).flatMap { str -> Int? in
                    guard str.count >= 4 else { return nil }
                    return Int(str.prefix(4))
                }
                let viewURL = (dict["collectionViewUrl"] as? String).flatMap { URL(string: $0) }
                let trackCount = dict["trackCount"] as? Int ?? 0

                return iTunesAlbum(collectionId: collectionId, name: name, artist: artistName, artworkURL: artworkURL, year: year, trackCount: trackCount, viewURL: viewURL)
            }
        }
        return []
    }

    func getAlbumTracks(collectionId: Int) async throws -> [AlbumTrack] {
        let url = URL(string: "https://itunes.apple.com/lookup?id=\(collectionId)&entity=song")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let results = json?["results"] as? [[String: Any]] else { return [] }

        return results.compactMap { dict -> AlbumTrack? in
            guard dict["wrapperType"] as? String == "track",
                  let name = dict["trackName"] as? String,
                  let artist = dict["artistName"] as? String else { return nil }
            let number = dict["trackNumber"] as? Int ?? 0
            let durationMs = dict["trackTimeMillis"] as? Int ?? 0
            let previewStr = dict["previewUrl"] as? String
            let previewURL = previewStr.flatMap { URL(string: $0) }
            return AlbumTrack(name: name, artistName: artist, durationMs: durationMs, trackNumber: number, previewURL: previewURL, userPlaycount: nil)
        }
    }

    struct iTunesAlbum {
        let collectionId: Int
        let name: String
        let artist: String
        let artworkURL: URL?
        let year: Int?
        let trackCount: Int
        let viewURL: URL?
    }
}
