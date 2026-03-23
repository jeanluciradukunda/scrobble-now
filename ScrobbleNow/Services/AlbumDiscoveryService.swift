import Foundation

actor AlbumDiscoveryService {
    private let lastfm = LastFMService()
    private let discogs = DiscogsService()
    private let musicbrainz = MusicBrainzService()
    private let itunes = iTunesService()
    private let wikidata = WikidataService()
    private let cache = CacheService.shared

    struct AlbumCandidate {
        var album: AlbumDetail
        var score: Double = 0
    }

    // MARK: - Discover album from all sources

    func discover(albumName: String, artistName: String, ctx: AlbumSearchContext? = nil) async throws -> [AlbumDetail] {
        let cacheKey = "\(artistName)|\(albumName)".lowercased()
        if let cached = await cache.getCachedAlbum(key: cacheKey) {
            return [cached]
        }

        let context = ctx ?? AlbumSearchContext(albumName: albumName, artistName: artistName)

        // Parallel 5-source fetch
        async let lfResults = fetchLastFM(album: albumName, artist: artistName)
        async let dcResults = fetchDiscogs(album: albumName, artist: artistName)
        async let mbResults = fetchMusicBrainz(album: albumName, artist: artistName)
        async let itResults = fetchiTunes(album: albumName, artist: artistName)
        async let wdResults = fetchWikidata(album: albumName, artist: artistName)

        var candidates: [AlbumCandidate] = []
        if let r = try? await lfResults { candidates.append(contentsOf: r) }
        if let r = try? await dcResults { candidates.append(contentsOf: r) }
        if let r = try? await mbResults { candidates.append(contentsOf: r) }
        if let r = try? await itResults { candidates.append(contentsOf: r) }
        if let r = try? await wdResults { candidates.append(contentsOf: r) }

        // Score all candidates
        let scored = candidates.map { score(candidate: $0, ctx: context) }
        let passing = scored.filter { $0.score >= context.minThreshold }

        guard !passing.isEmpty else {
            // Return unscored results if nothing passes threshold
            if let best = scored.sorted(by: { $0.score > $1.score }).first {
                return [best.album]
            }
            return []
        }

        // Deduplicate by normalized album name
        var deduped: [String: AlbumCandidate] = [:]
        for c in passing {
            let key = normalize(c.album.albumName)
            if let existing = deduped[key] {
                if c.score > existing.score { deduped[key] = c }
            } else {
                deduped[key] = c
            }
        }

        let sorted = deduped.values.sorted { $0.score > $1.score }.prefix(5).map { $0.album }

        // Merge external links from ALL passing candidates into the top result
        guard var best = sorted.first else { return [] }

        // Collect all links across sources
        var allLastfm = best.lastfmURL
        var allMusicbrainz = best.musicbrainzURL
        var allDiscogs = best.discogsURL
        var allAppleMusic = best.appleMusicURL
        var allArtwork = best.allArtworkURLs
        var allTags = best.tags
        var allTracks = best.tracks

        for candidate in passing.map({ $0.album }) {
            if allLastfm == nil { allLastfm = candidate.lastfmURL }
            if allMusicbrainz == nil { allMusicbrainz = candidate.musicbrainzURL }
            if allDiscogs == nil { allDiscogs = candidate.discogsURL }
            if allAppleMusic == nil { allAppleMusic = candidate.appleMusicURL }
            // Merge artwork URLs (deduplicated)
            for url in candidate.allArtworkURLs where !allArtwork.contains(url) {
                allArtwork.append(url)
            }
            // Use longer tag list
            if candidate.tags.count > allTags.count { allTags = candidate.tags }
            // Use longer track list
            if candidate.tracks.count > allTracks.count { allTracks = candidate.tracks }
        }

        // Build enriched top result
        best = AlbumDetail(
            albumName: best.albumName, artistName: best.artistName,
            artworkURL: allArtwork.first, allArtworkURLs: allArtwork,
            tracks: allTracks, tags: allTags,
            listeners: best.listeners, playcount: best.playcount, wikiSummary: best.wikiSummary,
            appleMusicURL: allAppleMusic, lastfmURL: allLastfm,
            musicbrainzURL: allMusicbrainz, discogsURL: allDiscogs,
            source: best.source, confidenceScore: best.confidenceScore,
            releaseYear: best.releaseYear
        )

        var results = Array(sorted)
        results[0] = best

        await cache.cacheAlbum(key: cacheKey, album: best)

        return results
    }

    // MARK: - Source Fetchers

    private func fetchLastFM(album: String, artist: String) async throws -> [AlbumCandidate] {
        let username = await MainActor.run { SettingsManager.shared.lastfmUsername }
        let json = try await lastfm.getAlbumInfo(artist: artist, album: album, user: username.isEmpty ? nil : username)

        guard let albumInfo = json["album"] as? [String: Any],
              let name = albumInfo["name"] as? String,
              let artistName = albumInfo["artist"] as? String else { return [] }

        let images = albumInfo["image"] as? [[String: Any]] ?? []
        let artworkURLs = images.compactMap { img -> URL? in
            guard let urlStr = img["#text"] as? String, !urlStr.isEmpty else { return nil }
            return URL(string: urlStr)
        }

        let tags = ((albumInfo["tags"] as? [String: Any])?["tag"] as? [[String: Any]])?
            .compactMap { $0["name"] as? String } ?? []

        let trackList = ((albumInfo["tracks"] as? [String: Any])?["track"] as? [[String: Any]]) ?? []
        let tracks = trackList.enumerated().map { (i, t) -> AlbumTrack in
            let tName = t["name"] as? String ?? ""
            let dur = t["duration"] as? Int ?? Int(t["duration"] as? String ?? "0") ?? 0
            let playcount = (t["@attr"] as? [String: Any])?["playcount"] as? Int
            return AlbumTrack(name: tName, artistName: artistName, durationMs: dur * 1000, trackNumber: i + 1, previewURL: nil, userPlaycount: playcount)
        }

        let listeners = Int(albumInfo["listeners"] as? String ?? "0")
        let playcount = Int(albumInfo["playcount"] as? String ?? "0")
        let wiki = (albumInfo["wiki"] as? [String: Any])?["summary"] as? String
        let url = (albumInfo["url"] as? String).flatMap { URL(string: $0) }

        let detail = AlbumDetail(
            albumName: name, artistName: artistName,
            artworkURL: artworkURLs.last, allArtworkURLs: artworkURLs,
            tracks: tracks, tags: tags,
            listeners: listeners, playcount: playcount, wikiSummary: wiki,
            appleMusicURL: nil, lastfmURL: url, musicbrainzURL: nil, discogsURL: nil,
            source: .lastfm, confidenceScore: 0, releaseYear: nil
        )
        return [AlbumCandidate(album: detail)]
    }

    private func fetchDiscogs(album: String, artist: String) async throws -> [AlbumCandidate] {
        let results = try await discogs.searchRelease(album: album, artist: artist)
        guard let first = results.first else { return [] }

        guard let detail = try await discogs.getReleaseDetail(id: first.releaseId) else { return [] }

        let albumDetail = AlbumDetail(
            albumName: detail.title, artistName: detail.artist,
            artworkURL: detail.artworkURLs.first, allArtworkURLs: detail.artworkURLs,
            tracks: detail.tracks, tags: detail.genres + detail.styles,
            listeners: nil, playcount: nil, wikiSummary: nil,
            appleMusicURL: nil, lastfmURL: nil, musicbrainzURL: nil, discogsURL: detail.discogsURL,
            source: .discogs, confidenceScore: 0, releaseYear: detail.year
        )
        return [AlbumCandidate(album: albumDetail)]
    }

    private func fetchMusicBrainz(album: String, artist: String) async throws -> [AlbumCandidate] {
        let groups = try await musicbrainz.searchAlbum(album: album, artist: artist)
        guard let first = groups.first else { return [] }

        let tracks = try await musicbrainz.getReleaseTracks(releaseGroupId: first.id)
        let coverURL = musicbrainz.getCoverArtURL(releaseGroupId: first.id)
        let mbURL = URL(string: "https://musicbrainz.org/release-group/\(first.id)")

        let detail = AlbumDetail(
            albumName: first.title, artistName: first.artist,
            artworkURL: coverURL, allArtworkURLs: coverURL != nil ? [coverURL!] : [],
            tracks: tracks, tags: [],
            listeners: nil, playcount: nil, wikiSummary: nil,
            appleMusicURL: nil, lastfmURL: nil, musicbrainzURL: mbURL, discogsURL: nil,
            source: .musicbrainz, confidenceScore: 0, releaseYear: first.year
        )
        return [AlbumCandidate(album: detail)]
    }

    private func fetchiTunes(album: String, artist: String) async throws -> [AlbumCandidate] {
        let results = try await itunes.searchAlbum(album: album, artist: artist)
        guard let first = results.first else { return [] }

        let tracks = try await itunes.getAlbumTracks(collectionId: first.collectionId)

        let detail = AlbumDetail(
            albumName: first.name, artistName: first.artist,
            artworkURL: first.artworkURL, allArtworkURLs: first.artworkURL != nil ? [first.artworkURL!] : [],
            tracks: tracks, tags: [],
            listeners: nil, playcount: nil, wikiSummary: nil,
            appleMusicURL: first.viewURL, lastfmURL: nil, musicbrainzURL: nil, discogsURL: nil,
            source: .apple, confidenceScore: 0, releaseYear: first.year
        )
        return [AlbumCandidate(album: detail)]
    }

    private func fetchWikidata(album: String, artist: String) async throws -> [AlbumCandidate] {
        let results = try await wikidata.searchAlbum(album: album, artist: artist)
        guard let first = results.first else { return [] }

        // If Wikidata gives us a MusicBrainz ID, use it for cover art
        var coverURL: URL?
        if let mbid = first.mbid {
            coverURL = URL(string: "https://coverartarchive.org/release-group/\(mbid)/front-500")
        }

        let detail = AlbumDetail(
            albumName: first.title, artistName: first.artist,
            artworkURL: coverURL, allArtworkURLs: coverURL != nil ? [coverURL!] : [],
            tracks: [], tags: [],
            listeners: nil, playcount: nil, wikiSummary: nil,
            appleMusicURL: nil, lastfmURL: nil, musicbrainzURL: nil, discogsURL: nil,
            source: .wikidata, confidenceScore: 0, releaseYear: nil
        )
        return [AlbumCandidate(album: detail)]
    }

    // MARK: - Scoring

    private func score(candidate: AlbumCandidate, ctx: AlbumSearchContext) -> AlbumCandidate {
        var c = candidate
        var total: Double = 0

        let albumNorm = normalize(c.album.albumName)
        let targetNorm = normalize(ctx.albumName)
        let artistNorm = normalize(c.album.artistName)
        let targetArtist = normalize(ctx.artistName)

        // 1. Title match (35%)
        let titleSim = levenshteinSimilarity(albumNorm, targetNorm)
        if albumNorm == targetNorm {
            total += ctx.weightTitle
        } else if titleSim > 0.85 {
            total += ctx.weightTitle * 0.9
        } else if titleSim > 0.7 {
            total += ctx.weightTitle * 0.5
        } else if albumNorm.contains(targetNorm) || targetNorm.contains(albumNorm) {
            total += ctx.weightTitle * 0.4
        }

        // 2. Artist match (30%)
        let artistSim = levenshteinSimilarity(artistNorm, targetArtist)
        if artistNorm == targetArtist {
            total += ctx.weightArtist
        } else if artistSim > 0.8 {
            total += ctx.weightArtist * 0.85
        } else if artistNorm.contains(targetArtist) || targetArtist.contains(artistNorm) {
            total += ctx.weightArtist * 0.6
        } else if artistSim > 0.5 {
            total += ctx.weightArtist * 0.3
        }

        // 3. Tracks (10%)
        if !c.album.tracks.isEmpty {
            total += ctx.weightTracks * (c.album.tracks.count >= 4 ? 1.0 : 0.5)
        }

        // 4. Source trust (15%) — multiplicative
        let trustMultiplier = 0.7 + (c.album.source.trustScore / 12.0) * 0.3
        total *= trustMultiplier
        total += (c.album.source.trustScore / 12.0) * (ctx.weightSource * 0.3)

        // 5. Content completeness (5%)
        if c.album.artworkURL != nil { total += ctx.weightContent * 0.5 }
        if !c.album.tracks.isEmpty { total += ctx.weightContent * 0.5 }

        c.score = min(100, total)
        return c
    }

    // MARK: - Helpers

    private func normalize(_ str: String) -> String {
        str.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private func levenshteinSimilarity(_ a: String, _ b: String) -> Double {
        if a.isEmpty || b.isEmpty { return 0 }
        let aChars = Array(a), bChars = Array(b)
        let aLen = aChars.count, bLen = bChars.count
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bLen + 1), count: aLen + 1)
        for i in 0...aLen { matrix[i][0] = i }
        for j in 0...bLen { matrix[0][j] = j }
        for i in 1...aLen {
            for j in 1...bLen {
                let cost = aChars[i-1] == bChars[j-1] ? 0 : 1
                matrix[i][j] = min(matrix[i-1][j]+1, matrix[i][j-1]+1, matrix[i-1][j-1]+cost)
            }
        }
        return 1.0 - Double(matrix[aLen][bLen]) / Double(max(aLen, bLen))
    }
}
