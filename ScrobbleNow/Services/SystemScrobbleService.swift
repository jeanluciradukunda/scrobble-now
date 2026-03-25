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
    @Published var isEnabled: Bool = true

    // MARK: - Dependencies

    #if os(macOS)
    private let bridge = MediaRemoteBridge.shared
    #elseif os(iOS)
    private let bridge = MPNowPlayingBridge.shared
    #endif
    private let lastfm = LastFMService()
    private var settings: SettingsManager { SettingsManager.shared }

    /// Called after a successful scrobble — use to refresh history
    var onScrobbleSuccess: (() -> Void)?

    // MARK: - Tracking State

    private var trackStartTime: Date?
    private var accumulatedPlayTime: TimeInterval = 0
    private var lastTickTime: Date?
    private var progressTimer: Timer?
    private var lastScrobbledTrack: String = "" // "artist|title" to prevent double scrobble

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
        let oldTrack = currentTrack

        // If there was a previous track and we hadn't scrobbled it yet,
        // force scrobble if we've listened for at least 30 seconds
        if let old = oldTrack, !didScrobbleCurrent, accumulatedPlayTime >= 30 {
            checkAndScrobble(track: old, force: true)
        }

        currentTrack = newTrack
        isPlaying = newTrack?.isPlaying ?? false
        didScrobbleCurrent = false
        trackStartTime = Date()
        lastTickTime = Date()

        // If the track is already mid-playback (app restart, or source reports elapsed time),
        // seed accumulated time from the track's elapsed position
        if let track = newTrack, track.elapsed > 0 {
            accumulatedPlayTime = track.elapsed
        } else {
            accumulatedPlayTime = 0
        }

        // Update progress immediately
        if let track = newTrack {
            let threshold = scrobbleThreshold(for: track)
            scrobbleProgress = threshold > 0 ? min(1, accumulatedPlayTime / threshold) : 0
            // If we've already passed the threshold (e.g., app restarted late into a song)
            if accumulatedPlayTime >= threshold {
                checkAndScrobble(track: track, force: true)
            }
        } else {
            scrobbleProgress = 0
        }

        // Fetch artwork from Last.fm if the track doesn't have any
        if let track = newTrack, track.artwork == nil, !track.artist.isEmpty {
            Task {
                await fetchArtwork(for: track)
            }
        }

        // Update Now Playing on Last.fm
        if let track = newTrack, isEnabled, isConnectorEnabled(for: track.sourceBundleId) {
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
        // Sync playing state from bridge
        isPlaying = bridge.isPlaying

        guard let track = currentTrack, isPlaying, !didScrobbleCurrent else {
            lastTickTime = Date()
            return
        }

        // Accumulate play time
        if let lastTick = lastTickTime {
            let delta = Date().timeIntervalSince(lastTick)
            if delta < 3 { // sanity check — don't count big gaps (sleep, etc.)
                accumulatedPlayTime += delta
            }
        }
        lastTickTime = Date()

        // Update progress
        let threshold = scrobbleThreshold(for: track)
        if threshold > 0 {
            scrobbleProgress = min(1, accumulatedPlayTime / threshold)
        }

        // Update the track's elapsed time for the UI progress bar
        if track.duration > 0 {
            let updatedTrack = SystemNowPlaying(
                title: track.title, artist: track.artist, album: track.album,
                duration: track.duration, elapsed: min(accumulatedPlayTime, track.duration),
                playbackRate: track.playbackRate, artwork: track.artwork,
                sourceBundleId: track.sourceBundleId, sourceAppName: track.sourceAppName,
                timestamp: track.timestamp
            )
            currentTrack = updatedTrack
            bridge.activeSources[track.sourceBundleId] = updatedTrack
            if bridge.currentTrack?.sourceBundleId == track.sourceBundleId {
                bridge.currentTrack = updatedTrack
            }
        }

        // Check if we should scrobble
        if accumulatedPlayTime >= threshold && !didScrobbleCurrent {
            checkAndScrobble(track: track, force: true)
        }

        // Also refresh the bridge data periodically for elapsed time updates
        #if os(macOS)
        bridge.pollMediaRemote()
        #endif
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

    // MARK: - Scrobble Rules

    /// Returns the number of seconds of play time required before scrobbling.
    ///
    /// Rules (matching Last.fm/Web Scrobbler):
    /// - Known duration: scrobble at `scrobbleThresholdPercent`% of duration, capped at 4 min
    /// - Unknown duration (YouTube etc): scrobble at 60 seconds
    /// - Either way, never scrobble before `minTrackDuration` seconds (default 30s)
    private func scrobbleThreshold(for track: SystemNowPlaying) -> TimeInterval {
        let pct = settings.scrobbleThresholdPercent / 100.0 // default 50%
        let maxSeconds: TimeInterval = 240 // 4 minutes cap
        let minSeconds = TimeInterval(settings.minTrackDuration) // default 30s

        if track.duration > 0 {
            let pctThreshold = track.duration * pct
            return max(minSeconds, min(pctThreshold, maxSeconds))
        }

        // Unknown duration — use 60 seconds (reasonable middle ground)
        return max(minSeconds, 60)
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
            let trackInfoURL = URL(string: "https://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=\(KeychainService.lastfmApiKey)&artist=\(track.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&track=\(track.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&format=json")!
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
        let artistURL = URL(string: "https://ws.audioscrobbler.com/2.0/?method=artist.getInfo&api_key=\(KeychainService.lastfmApiKey)&artist=\(track.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&format=json")!

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

    private func checkAndScrobble(track: SystemNowPlaying, force: Bool) {
        guard isEnabled else { return }
        guard isConnectorEnabled(for: track.sourceBundleId) else { return }

        // Minimum duration filter
        if track.duration > 0 && track.duration < Double(settings.minTrackDuration) { return }

        // Check threshold
        let threshold = scrobbleThreshold(for: track)
        guard force || accumulatedPlayTime >= threshold else { return }

        // Prevent double scrobble
        let key = "\(track.artist)|\(track.title)"
        guard key != lastScrobbledTrack else { return }

        // Submit!
        lastScrobbledTrack = key
        didScrobbleCurrent = true
        totalScrobbled += 1

        let timestamp = Int(Date().timeIntervalSince1970)
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
                await MainActor.run { onScrobbleSuccess?() }
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

        // Auto-disable podcasts
        let isPodcast = bundleId.contains("podcast") || bundleId.contains("overcast") || bundleId.contains("pocketcast")

        let connector = AppConnector(
            bundleId: bundleId,
            displayName: name,
            enabled: !isPodcast
        )
        connectors.append(connector)
        print("[Connector] Discovered: \(name) (\(bundleId)) — \(isPodcast ? "disabled (podcast)" : "enabled")")
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
