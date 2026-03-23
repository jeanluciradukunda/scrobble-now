import Foundation

struct ScrobbledTrack: Identifiable, Equatable {
    let id: String
    let name: String
    let artistName: String
    let albumName: String
    let albumArtworkURL: URL?
    let timestamp: Date
    let isNowPlaying: Bool
    let loved: Bool
    let lastfmURL: URL?
    let mbid: String?

    var displayTime: String {
        if isNowPlaying { return "Now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    static func == (lhs: ScrobbledTrack, rhs: ScrobbledTrack) -> Bool {
        lhs.id == rhs.id
    }
}
