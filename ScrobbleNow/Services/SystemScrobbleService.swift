import SwiftUI
import Combine

/// Core scrobble engine — detects track changes from MediaRemote,
/// tracks elapsed time, applies scrobble rules, submits to Last.fm.
@MainActor
class SystemScrobbleService: ObservableObject {
    static let shared = SystemScrobbleService()

    // MARK: - Published State

    @Published var currentTrack: SystemNowPlaying?
    @Published var isPlaying: Bool = false
    @Published var scrobbleProgress: Double = 0  // 0-1, how close to scrobble threshold
    @Published var didScrobbleCurrent: Bool = false
    @Published var totalScrobbled: Int = 0

    // MARK: - Dependencies

    #if os(macOS)
    private let bridge = MediaRemoteBridge.shared
    #elseif os(iOS)
    private let bridge = MPNowPlayingBridge.shared
    #endif
    private let lastfm = LastFMService()
    private var settings: SettingsManager { SettingsManager.shared }
    var isEnabled: Bool { settings.scrobbleEnabled }

    /// Called after a successful scrobble — use to refresh history
    var onScrobbleSuccess: (() -> Void)?

    // MARK: - Tracking State

    private var engine = ScrobbleEngine(lastScrobbled: SystemScrobbleService.loadLastScrobble())
    private var persistedLastScrobble = SystemScrobbleService.loadLastScrobble()
    private var progressTimer: Timer?
    private var rules: ScrobbleRules {
        ScrobbleRules(thresholdPercent: settings.scrobbleThresholdPercent,
                      minTrackDuration: TimeInterval(settings.minTrackDuration))
    }

    // MARK: - Connector Toggles (per-app)

    @Published var connectors: [AppConnector] = [] {
        didSet { saveConnectors() }
    }

    private init() {
        loadConnectors()
        setupBridge()
        startProgressTimer()
        startRetryTimer()
    }

    // MARK: - Bridge Setup

    private func setupBridge() {
        bridge.onTrackChange = { [weak self] track in
            Task { @MainActor in
                self?.handleTrackChange(track)
            }
        }

        // Sync initial state
        if let track = bridge.currentTrack {
            handleTrackChange(track)
        }
    }

    // MARK: - Track Change Handler

    private func handleTrackChange(_ newTrack: SystemNowPlaying?) {
        let scrobbles = engine.trackChanged(to: newTrack, now: Date(), rules: rules, isAllowed: canScrobble)
        currentTrack = newTrack
        isPlaying = newTrack?.isPlaying ?? false
        syncEngineState()
        scrobbles.forEach(submit)

        // Fetch artwork from Last.fm if the track doesn't have any
        if let track = newTrack, track.artwork == nil, !track.artist.isEmpty {
            Task {
                await fetchArtwork(for: track)
            }
        }

        // Update Now Playing on Last.fm
        if let track = newTrack, canScrobble(track) {
            Task {
                try? await lastfm.updateNowPlaying(
                    artist: track.artist,
                    track: track.title,
                    album: track.album
                )
            }
        }

        // Auto-discover new apps
        if let track = newTrack {
            discoverApp(bundleId: track.sourceBundleId, name: track.sourceAppName)
        }
    }

    // MARK: - Progress Timer (ticks every second)

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        isPlaying = bridge.isPlaying
        let source = engine.current.flatMap { bridge.activeSources[$0.sourceBundleId] }
        let playing = Self.countsPlayTime(bridgeIsPlaying: isPlaying, source: source)
        let canRepeat = Self.canDetectRepeats(bundleId: engine.current?.sourceBundleId ?? "")
        let scrobbles = engine.tick(isPlaying: playing, canRepeat: canRepeat, now: Date(), rules: rules,
                                    isAllowed: canScrobble)

        // Update the track's elapsed time for the UI progress bar
        if playing, let track = currentTrack, track.duration > 0 {
            let updatedTrack = SystemNowPlaying(
                title: track.title, artist: track.artist, album: track.album,
                duration: track.duration, elapsed: min(engine.accumulatedPlayTime, track.duration),
                playbackRate: source?.playbackRate ?? track.playbackRate, artwork: track.artwork,
                sourceBundleId: track.sourceBundleId, sourceAppName: track.sourceAppName,
                timestamp: track.timestamp
            )
            currentTrack = updatedTrack
            bridge.activeSources[track.sourceBundleId] = updatedTrack
            if bridge.currentTrack?.sourceBundleId == track.sourceBundleId {
                bridge.currentTrack = updatedTrack
            }
        }

        syncEngineState()
        scrobbles.forEach(submit)

        // Also refresh the bridge data periodically for elapsed time updates
        #if os(macOS)
        if playing { bridge.pollMediaRemote() }
        #endif
    }

    private func syncEngineState() {
        scrobbleProgress = engine.progress(rules: rules)
        didScrobbleCurrent = engine.didScrobbleCurrent
        if let record = engine.lastScrobbled, record != persistedLastScrobble,
           let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: Self.lastScrobbleKey)
            persistedLastScrobble = record
        }
    }

    private static let lastScrobbleKey = "sn_last_scrobble"

    private static func loadLastScrobble() -> ScrobbleRecord? {
        guard let data = UserDefaults.standard.data(forKey: lastScrobbleKey) else { return nil }
        return try? JSONDecoder().decode(ScrobbleRecord.self, from: data)
    }

    /// bridge.isPlaying covers every source and stays true while another one plays, so play time counts only
    /// while the play's own source is playing; otherwise a paused track keeps accruing time and repeating.
    nonisolated static func countsPlayTime(bridgeIsPlaying: Bool, source: SystemNowPlaying?) -> Bool {
        bridgeIsPlaying && (source?.isPlaying ?? false)
    }

    /// Browser tabs report playing whenever a music tab is open, so a repeat cannot be told from a paused tab.
    nonisolated static func canDetectRepeats(bundleId: String) -> Bool {
        !browserBundleIds.contains(bundleId)
    }

    private nonisolated static let browserBundleIds: Set<String> = [
        "com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser", "com.brave.Browser",
        "org.mozilla.firefox", "com.microsoft.edgemac"
    ]

    private func canScrobble(_ track: SystemNowPlaying) -> Bool {
        isEnabled && isConnectorEnabled(for: track.sourceBundleId)
            && !(settings.filterPodcasts && Self.isPodcastApp(track.sourceBundleId))
    }

    nonisolated static func isPodcastApp(_ bundleId: String) -> Bool {
        let id = bundleId.lowercased()
        return ["podcast", "overcast", "pocketcast", "castro"].contains { id.contains($0) }
    }

    // MARK: - Retry Timer

    private func startRetryTimer() {
        // Retry failed scrobbles every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                let result = await ScrobbleCache.shared.retryPending(using: self.lastfm)
                if result.succeeded > 0 {
                    print("[Scrobble] Retry: \(result.succeeded) succeeded, \(result.failed) still pending")
                    await MainActor.run { self.totalScrobbled += result.succeeded }
                }
            }
        }
    }

    // MARK: - Artwork Fetching

    private func fetchArtwork(for track: SystemNowPlaying) async {
        do {
            // Try Last.fm album.getInfo first — fast and reliable
            let albumName = track.album.isEmpty ? track.title : track.album
            let info = try await lastfm.getAlbumInfo(artist: track.artist, album: albumName)

            if let albumInfo = info["album"] as? [String: Any],
               let images = albumInfo["image"] as? [[String: Any]] {
                // Get largest image
                for size in ["extralarge", "large", "medium"] {
                    if let img = images.first(where: { ($0["size"] as? String) == size }),
                       let urlStr = img["#text"] as? String, !urlStr.isEmpty,
                       let url = URL(string: urlStr) {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = PlatformImage(data: data) {
                            // Update the track in the bridge with artwork
                            let updated = track.withArtwork(image)
                            bridge.activeSources[track.sourceBundleId] = updated
                            if bridge.currentTrack?.sourceBundleId == track.sourceBundleId {
                                bridge.currentTrack = updated
                            }
                            currentTrack = updated
                            return
                        }
                    }
                }
            }

            // If album search failed, try track.getInfo
            let trackInfoURL = URL(string: "https://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=\(KeychainService.lastfmApiKey)&artist=\(track.artist.queryValueEncoded)&track=\(track.title.queryValueEncoded)&format=json")!
            let (trackData, _) = try await URLSession.shared.data(from: trackInfoURL)
            if let trackJson = try JSONSerialization.jsonObject(with: trackData) as? [String: Any],
               let trackInfo = trackJson["track"] as? [String: Any],
               let albumInfo = trackInfo["album"] as? [String: Any],
               let images = albumInfo["image"] as? [[String: Any]] {
                for size in ["extralarge", "large", "medium"] {
                    if let img = images.first(where: { ($0["size"] as? String) == size }),
                       let urlStr = img["#text"] as? String, !urlStr.isEmpty,
                       let url = URL(string: urlStr) {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = PlatformImage(data: data) {
                            let updated = track.withArtwork(image)
                            bridge.activeSources[track.sourceBundleId] = updated
                            if bridge.currentTrack?.sourceBundleId == track.sourceBundleId {
                                bridge.currentTrack = updated
                            }
                            currentTrack = updated
                            return
                        }
                    }
                }
            }
        } catch {
            // Last.fm failed
        }

        // Fallback: YouTube thumbnail if it's a YouTube source
        if track.sourceBundleId == "com.google.Chrome" || track.sourceAppName.contains("YouTube") {
            await fetchYouTubeThumbnail(for: track)
        }
    }

    private func fetchYouTubeThumbnail(for track: SystemNowPlaying) async {
        // Simpler: use Last.fm artist image as fallback
        let artistURL = URL(string: "https://ws.audioscrobbler.com/2.0/?method=artist.getInfo&api_key=\(KeychainService.lastfmApiKey)&artist=\(track.artist.queryValueEncoded)&format=json")!

        do {
            let (data, _) = try await URLSession.shared.data(from: artistURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let artist = json["artist"] as? [String: Any],
               let images = artist["image"] as? [[String: Any]] {
                for size in ["extralarge", "large", "medium"] {
                    if let img = images.first(where: { ($0["size"] as? String) == size }),
                       let urlStr = img["#text"] as? String, !urlStr.isEmpty,
                       let url = URL(string: urlStr) {
                        let (imgData, _) = try await URLSession.shared.data(from: url)
                        if let image = PlatformImage(data: imgData) {
                            let updated = track.withArtwork(image)
                            bridge.activeSources[track.sourceBundleId] = updated
                            if bridge.currentTrack?.sourceBundleId == track.sourceBundleId {
                                bridge.currentTrack = updated
                            }
                            currentTrack = updated
                            return
                        }
                    }
                }
            }
        } catch {}

        // Last resort: YouTube video thumbnail directly
        if let videoId = findCurrentYouTubeVideoId() {
            let thumbURL = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")!
            do {
                let (data, _) = try await URLSession.shared.data(from: thumbURL)
                if let image = PlatformImage(data: data) {
                    let updated = track.withArtwork(image)
                    bridge.activeSources[track.sourceBundleId] = updated
                    if bridge.currentTrack?.sourceBundleId == track.sourceBundleId {
                        bridge.currentTrack = updated
                    }
                    currentTrack = updated
                }
            } catch {}
        }
    }

    private func findCurrentYouTubeVideoId() -> String? {
        #if os(macOS)
        // Check the last browser title key for a YouTube URL
        let lastTitle = bridge.lastBrowserTitle
        // The bridge stores "bundleId:title" — we need to find the URL from the last poll
        // For now, return nil — we'll improve this later
        return nil
        #else
        return nil
        #endif
    }

    // MARK: - Scrobble Submission

    private func submit(_ scrobble: PendingScrobble) {
        let track = scrobble.track
        let timestamp = scrobble.timestamp
        Task {
            let entry = ScrobbleCacheEntry(artist: track.artist, track: track.title, album: track.album, timestamp: timestamp)
            do {
                try await lastfm.scrobble(
                    artist: track.artist,
                    track: track.title,
                    album: track.album,
                    timestamp: timestamp
                )
                print("[Scrobble] ✓ \(track.artist) — \(track.title) (via \(track.sourceAppName))")
                await ScrobbleCache.shared.logSuccess(artist: track.artist, track: track.title, album: track.album, timestamp: timestamp)
                await MainActor.run {
                    totalScrobbled += 1
                    onScrobbleSuccess?()
                }
            } catch let error as LastFMService.LastFMError where error.disposition == .drop {
                print("[Scrobble] ✗ Not scrobbled: \(error.localizedDescription)")
                await ScrobbleCache.shared.logHistory(entry, success: false)
            } catch {
                print("[Scrobble] ✗ Failed, queued for retry: \(error.localizedDescription)")
                await ScrobbleCache.shared.queueForRetry(entry)
            }
        }
    }

    // MARK: - Connector Management

    func isConnectorEnabled(for bundleId: String) -> Bool {
        if bundleId.isEmpty { return true }
        return connectors.first(where: { $0.bundleId == bundleId })?.enabled ?? true
    }

    func toggleConnector(bundleId: String) {
        if let idx = connectors.firstIndex(where: { $0.bundleId == bundleId }) {
            connectors[idx].enabled.toggle()
        }
    }

    private func discoverApp(bundleId: String, name: String) {
        guard !bundleId.isEmpty else { return }
        guard !connectors.contains(where: { $0.bundleId == bundleId }) else { return }

        connectors.append(AppConnector(bundleId: bundleId, displayName: name, enabled: true))
        print("[Connector] Discovered: \(name) (\(bundleId))")
    }

    private func loadConnectors() {
        if let data = UserDefaults.standard.data(forKey: "sn_connectors"),
           let decoded = try? JSONDecoder().decode([AppConnector].self, from: data) {
            connectors = decoded
        }
    }

    private func saveConnectors() {
        if let data = try? JSONEncoder().encode(connectors) {
            UserDefaults.standard.set(data, forKey: "sn_connectors")
        }
    }
}

// MARK: - App Connector

struct AppConnector: Identifiable, Codable, Equatable {
    var id: String { bundleId }
    let bundleId: String
    let displayName: String
    var enabled: Bool
}
