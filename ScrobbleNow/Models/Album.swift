import Foundation

enum AlbumSource: String {
    case lastfm = "lastfm"
    case discogs = "discogs"
    case musicbrainz = "musicbrainz"
    case apple = "apple"
    case wikidata = "wikidata"

    var label: String {
        switch self {
        case .lastfm: return "Last.fm"
        case .discogs: return "Discogs"
        case .musicbrainz: return "MusicBrainz"
        case .apple: return "iTunes"
        case .wikidata: return "Wikidata"
        }
    }

    var trustScore: Double {
        switch self {
        case .musicbrainz: return 12
        case .discogs: return 11
        case .lastfm: return 10
        case .apple: return 8
        case .wikidata: return 7
        }
    }
}

struct AlbumDetail: Identifiable {
    let id = UUID()
    let albumName: String
    let artistName: String
    let artworkURL: URL?
    let allArtworkURLs: [URL]
    let tracks: [AlbumTrack]
    let tags: [String]
    let listeners: Int?
    let playcount: Int?
    let wikiSummary: String?
    let appleMusicURL: URL?
    let lastfmURL: URL?
    let musicbrainzURL: URL?
    let discogsURL: URL?
    let source: AlbumSource
    let confidenceScore: Double
    let releaseYear: Int?
}

struct AlbumTrack: Identifiable {
    let id = UUID()
    let name: String
    let artistName: String
    let durationMs: Int
    let trackNumber: Int
    let previewURL: URL?
    let userPlaycount: Int?

    var durationFormatted: String {
        let totalSeconds = durationMs / 1000
        let min = totalSeconds / 60
        let sec = totalSeconds % 60
        return "\(min):\(String(format: "%02d", sec))"
    }
}

struct AlbumSearchContext {
    let albumName: String
    let artistName: String
    var weightTitle: Double = 35
    var weightArtist: Double = 30
    var weightTracks: Double = 10
    var weightYear: Double = 5
    var weightSource: Double = 15
    var weightContent: Double = 5
    var minThreshold: Double = 40
}

struct TopAlbumEntry: Identifiable {
    let id = UUID()
    let albumName: String
    let artistName: String
    let playcount: Int
    let artworkURL: URL?
    let lastfmURL: URL?
}

struct TopArtistEntry: Identifiable {
    let id = UUID()
    let name: String
    let playcount: Int
    let imageURL: URL?
    let lastfmURL: URL?
}
