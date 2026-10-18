import Foundation

enum AlbumNormalisation {
    /// Lowercased, diacritics folded, punctuation dropped; letters, marks and digits of any script kept.
    static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .replacingOccurrences(of: "[^\\p{L}\\p{M}\\p{N} ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static let editionPatterns = [
        "\\s*[\\(\\[]\\s*(deluxe|special|expanded|complete|remastered|anniversary|bonus|limited|collector|standard|explicit|clean)[^\\)\\]]*[\\)\\]]",
        "\\s*[\\(\\[]\\s*\\d+(st|nd|rd|th) anniversary[^\\)\\]]*[\\)\\]]",
        "\\s*-\\s*(ep|single|lp)$"
    ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }

    /// "OK Computer (Remastered)" and "Album - EP" become "OK Computer" and "Album".
    static func withoutEdition(_ album: String) -> String {
        editionPatterns.reduce(album) { result, regex in
            regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        .trimmingCharacters(in: .whitespaces)
    }

    /// "Kanye West & Travis Scott" becomes "Kanye West".
    static func primaryArtist(_ artist: String) -> String {
        let lowered = artist.lowercased()
        for delimiter in [" & ", " feat. ", " feat ", " ft. ", " ft ", " featuring ", " with ", " x ", ", "] {
            if let range = lowered.range(of: delimiter) {
                return String(artist[artist.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        return artist.trimmingCharacters(in: .whitespaces)
    }

    static func identityKey(album: String, artist: String) -> String {
        // Titles with no letters or digits (Ed Sheeran's ÷, +, =) normalise to "" and would all merge.
        let title = normalize(withoutEdition(album))
        let titleKey = title.isEmpty ? album.lowercased().trimmingCharacters(in: .whitespaces) : title
        return "\(titleKey)|\(normalize(primaryArtist(artist)))"
    }

    /// Editions and featured-artist variants of one album collapse into the first, most-played entry, with plays summed.
    static func mergingDuplicates(_ entries: [TopAlbumEntry]) -> [TopAlbumEntry] {
        var merged: [TopAlbumEntry] = []
        var indexByKey: [String: Int] = [:]
        for entry in entries {
            let key = identityKey(album: entry.albumName, artist: entry.artistName)
            if let index = indexByKey[key] {
                let kept = merged[index]
                merged[index] = TopAlbumEntry(albumName: kept.albumName, artistName: kept.artistName,
                                              playcount: kept.playcount + entry.playcount,
                                              artworkURL: kept.artworkURL ?? entry.artworkURL, lastfmURL: kept.lastfmURL)
            } else {
                indexByKey[key] = merged.count
                merged.append(entry)
            }
        }
        return merged.sorted { $0.playcount > $1.playcount }
    }
}
