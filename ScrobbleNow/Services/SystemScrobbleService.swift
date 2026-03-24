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

    private let bridge = MediaRemoteBridge.shared
    private let lastfm = LastFMService()
    private var settings: SettingsManager { SettingsManager.shared }

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

        // If there was a previous track and we hadn't scrobbled it yet, check if we should
        if let old = oldTrack, !didScrobbleCurrent {
            checkAndScrobble(track: old, force: false)
        }

        currentTrack = newTrack
        isPlaying = newTrack?.isPlaying ?? false
        didScrobbleCurrent = false
        scrobbleProgress = 0
        accumulatedPlayTime = 0
        trackStartTime = Date()
        lastTickTime = Date()

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

        // Check if we should scrobble
        if accumulatedPlayTime >= threshold && !didScrobbleCurrent {
            checkAndScrobble(track: track, force: true)
        }

        // Also refresh the bridge data periodically for elapsed time updates
        bridge.pollMediaRemote()
    }

    // MARK: - Scrobble Rules

    /// Returns the number of seconds of play time required before scrobbling
    private func scrobbleThreshold(for track: SystemNowPlaying) -> TimeInterval {
        let pct = settings.scrobbleThresholdPercent / 100.0 // default 50%
        let minSeconds: TimeInterval = 240 // 4 minutes

        if track.duration > 0 {
            let pctThreshold = track.duration * pct
            return min(pctThreshold, minSeconds)
        }

        // Unknown duration — use 4 minutes
        return minSeconds
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
            do {
                try await lastfm.scrobble(
                    artist: track.artist,
                    track: track.title,
                    album: track.album,
                    timestamp: timestamp
                )
                print("[Scrobble] ✓ \(track.artist) — \(track.title) (via \(track.sourceAppName))")
            } catch {
                print("[Scrobble] ✗ Failed: \(error.localizedDescription)")
                // TODO: Queue for retry (Task 15)
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
