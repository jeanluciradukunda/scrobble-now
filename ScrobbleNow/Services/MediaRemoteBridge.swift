#if os(macOS)
import AppKit
import Combine
import Foundation

/// System-wide Now Playing detection — supports multiple simultaneous sources.
@MainActor
class MediaRemoteBridge: ObservableObject {
    static let shared = MediaRemoteBridge()

    /// ALL currently/recently playing sources
    @Published var activeSources: [String: SystemNowPlaying] = [:] // keyed by bundleId

    /// The primary (most recent) playing source
    @Published var currentTrack: SystemNowPlaying?
    @Published var isPlaying: Bool = false

    var onTrackChange: ((SystemNowPlaying?) -> Void)?
    var onArtworkLoaded: ((SystemNowPlaying) -> Void)?

    @Published private(set) var adapterStatus: AdapterStatus = .off

    private var pollTimer: Timer?
    private let adapter = MediaRemoteAdapterSource()
    private var adapterBundleId: String?
    private var settingsObserver: AnyCancellable?
    private var adapterIsHealthy: Bool { adapterStatus == .running }

    // MediaRemote framework
    private var handle: UnsafeMutableRawPointer?
    private typealias GetInfoFunc = @convention(c) (DispatchQueue, @escaping (CFDictionary) -> Void) -> Void
    private typealias RegisterFunc = @convention(c) (DispatchQueue) -> Void
    private var _getNowPlayingInfo: GetInfoFunc?
    private var _registerForNotifications: RegisterFunc?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if let handle {
            if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
                _getNowPlayingInfo = unsafeBitCast(sym, to: GetInfoFunc.self)
            }
            if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
                _registerForNotifications = unsafeBitCast(sym, to: RegisterFunc.self)
            }
        }
    }

    // MARK: - Start

    func startListening() {
        _registerForNotifications?(DispatchQueue.main)

        let dnc = DistributedNotificationCenter.default()

        // Spotify — instant notifications
        dnc.addObserver(self, selector: #selector(spotifyChanged(_:)),
                        name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil)

        // Apple Music — instant notifications
        dnc.addObserver(self, selector: #selector(musicChanged(_:)),
                        name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil)

        // Chrome / browsers — MediaRemote notifications
        for name in [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ] {
            NotificationCenter.default.addObserver(self, selector: #selector(mediaRemoteChanged),
                                                   name: NSNotification.Name(name), object: nil)
        }

        // Also try loading the actual notification name symbols from the framework
        if let handle {
            for symbol in [
                "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            ] {
                if let ptr = dlsym(handle, symbol) {
                    let cfStr = ptr.assumingMemoryBound(to: CFString.self).pointee
                    let name = NSNotification.Name(cfStr as String)
                    NotificationCenter.default.addObserver(self, selector: #selector(mediaRemoteChanged),
                                                           name: name, object: nil)
                }
            }
        }

        // Try MediaRemote once to see if it works
        pollMediaRemote()

        // Poll based on what's available
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if Self.pollsMediaRemote(adapterRunning: self.adapterIsHealthy, mediaRemoteActive: self.mediaRemoteIsActive) {
                    self.pollMediaRemote()
                }
                self.cleanStaleSources()
            }
        }

        print("[NowPlaying] ✓ Listening (Spotify + Music\(mediaRemoteIsActive ? " + MediaRemote" : ""))")

        setUpAdapter()
    }

    func stopListening() {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        pollTimer?.invalidate()
        settingsObserver = nil
        adapter.stop()
    }

    // MARK: - mediaremote-adapter (opt-in)

    private func setUpAdapter() {
        adapter.appName = { [weak self] in self?.appName(for: $0) ?? $0 }
        adapter.onStatusChange = { [weak self] in self?.adapterStatus = $0 }
        adapter.onUpdate = { [weak self] in self?.handleAdapterUpdate($0) }
        applyAdapterSetting()
        settingsObserver = SettingsManager.shared.objectWillChange.sink { [weak self] _ in
            // objectWillChange fires before the new value is stored.
            DispatchQueue.main.async { self?.applyAdapterSetting() }
        }
    }

    private func applyAdapterSetting() {
        let wanted = SettingsManager.shared.useMediaRemoteAdapter
        if wanted, adapterStatus == .off {
            adapter.start()
        } else if !wanted, adapterStatus != .off {
            adapter.stop()
        }
    }

    private func handleAdapterUpdate(_ update: AdapterUpdate) {
        switch update {
        case .track(let track):
            adapterBundleId = track.sourceBundleId
            if track.isPlaying {
                updateSource(track)
            } else {
                if activeSources[track.sourceBundleId] == nil { activeSources[track.sourceBundleId] = track }
                markPaused(track.sourceBundleId)
            }
        case .nothingPlaying:
            if let adapterBundleId { markPaused(adapterBundleId) }
        }
    }

    // MARK: - Spotify

    @objc private func spotifyChanged(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        let state = info["Player State"] as? String ?? ""

        if state != "Playing" {
            markPaused("com.spotify.client")
            return
        }

        let title = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String ?? ""
        let duration = (info["Duration"] as? Double ?? 0) / 1000.0

        guard !title.isEmpty else { return }

        let track = SystemNowPlaying(
            title: title, artist: artist, album: album,
            duration: duration, elapsed: 0, playbackRate: 1.0,
            artwork: nil, sourceBundleId: "com.spotify.client",
            sourceAppName: "Spotify", timestamp: Date()
        )
        updateSource(track)

        // Artwork arrives later; applying it only to the still-current track keeps a slow fetch for an
        // earlier track from making that track current again.
        Task {
            guard let artwork = await loadSpotifyArtwork(),
                  let latest = activeSources[track.sourceBundleId], latest == track else { return }
            let withArtwork = latest.withArtwork(artwork)
            activeSources[track.sourceBundleId] = withArtwork
            if currentTrack == track { currentTrack = withArtwork }
            onArtworkLoaded?(withArtwork)
        }
    }

    // MARK: - Apple Music

    @objc private func musicChanged(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        let state = info["Player State"] as? String ?? ""

        if state != "Playing" {
            markPaused("com.apple.Music")
            return
        }

        let title = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String ?? ""
        let duration = (info["Total Time"] as? Double ?? 0) / 1000.0

        guard !title.isEmpty else { return }

        let track = SystemNowPlaying(
            title: title, artist: artist, album: album,
            duration: duration, elapsed: 0, playbackRate: 1.0,
            artwork: nil, sourceBundleId: "com.apple.Music",
            sourceAppName: "Music", timestamp: Date()
        )
        updateSource(track)
    }

    private var mediaRemoteIsActive: Bool = false

    // MARK: - MediaRemote (fallback for other apps)

    @objc private func mediaRemoteChanged(_ notification: Notification) {
        pollMediaRemote()
    }

    func pollMediaRemote() {
        guard !adapterIsHealthy, !mediaRemoteBlocked, let getInfo = _getNowPlayingInfo else { return }

        getInfo(DispatchQueue.main) { [weak self] cfDict in
            guard let info = cfDict as NSDictionary as? [String: Any] else { return }
            Task { @MainActor in
                self?.processMediaRemoteInfo(info)
            }
        }
    }

    private var hasLoggedKeys = false

    /// Set once MediaRemote has refused us on a macOS that restricts it, so it is not asked again this session.
    private var mediaRemoteBlocked = false

    /// macOS 15.4 stopped returning now-playing data to third-party apps; before that, an empty reply only
    /// meant nothing was playing.
    /// There is no browser-tab fallback when both are off: a tab's title gives no play state, so an idle tab
    /// scrobbled every track (issue #43). Browser tabs come only from the adapter or a working MediaRemote.
    nonisolated static func pollsMediaRemote(adapterRunning: Bool, mediaRemoteActive: Bool) -> Bool {
        !adapterRunning && mediaRemoteActive
    }

    nonisolated static func restrictsMediaRemote(_ version: OperatingSystemVersion) -> Bool {
        (version.majorVersion, version.minorVersion) >= (15, 4)
    }

    private func processMediaRemoteInfo(_ info: [String: Any]) {
        guard !info.isEmpty else {
            mediaRemoteIsActive = false
            if !mediaRemoteBlocked, Self.restrictsMediaRemote(ProcessInfo.processInfo.operatingSystemVersion) {
                mediaRemoteBlocked = true
                print("[MediaRemote] Not available to this app on this macOS; using notifications.")
            }
            return
        }

        mediaRemoteIsActive = true

        if !hasLoggedKeys {
            hasLoggedKeys = true
            print("[MediaRemote] ✓ Got data! Keys: \(info.keys.sorted().joined(separator: ", "))")
            for (key, value) in info.sorted(by: { $0.key < $1.key }) {
                if let data = value as? Data {
                    print("[MediaRemote]   \(key) = <Data \(data.count) bytes>")
                } else {
                    print("[MediaRemote]   \(key) = \(String(describing: value).prefix(80))")
                }
            }
        }

        let rawTitle = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        guard !rawTitle.isEmpty else { return }

        let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        let title = Self.cleanedTitle(rawTitle, artist: artist)
        let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? ""
        let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
        let elapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0
        let rate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
        let bundleId = info["kMRMediaRemoteNowPlayingInfoQueueItemBundleIdentifier"] as? String ?? "system.mediaremote"

        // Don't override Spotify/Music with MediaRemote data (they have better DistributedNotification data)
        if (bundleId == "com.spotify.client" || bundleId == "com.apple.Music"),
           let existing = activeSources[bundleId],
           Date().timeIntervalSince(existing.timestamp) < 10 {
            return
        }

        var artwork: PlatformImage?
        if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, !data.isEmpty {
            artwork = PlatformImage(data: data)
        }

        let track = SystemNowPlaying(
            title: title, artist: artist, album: album,
            duration: duration, elapsed: elapsed, playbackRate: rate,
            artwork: artwork, sourceBundleId: bundleId.isEmpty ? "system" : bundleId,
            sourceAppName: bundleId.isEmpty ? "System" : appName(for: bundleId),
            timestamp: Date()
        )

        updateSource(track)
    }

    /// Strips a leading "Artist - " and common YouTube suffixes from a title that has a separate artist field.
    nonisolated static func cleanedTitle(_ rawTitle: String, artist: String) -> String {
        var title = rawTitle
        if !artist.isEmpty && title.lowercased().hasPrefix(artist.lowercased()) {
            let afterArtist = title.dropFirst(artist.count)
            for sep in [" - ", " – ", " — "] where afterArtist.hasPrefix(sep) {
                title = String(afterArtist.dropFirst(sep.count))
                break
            }
        }
        for suffix in [" (official video)", " (official audio)", " (official music video)",
                       " (lyric video)", " (lyrics)", " (audio)", " (visualizer)", " (mv)"]
        where title.lowercased().hasSuffix(suffix) {
            title = String(title.dropLast(suffix.count))
        }
        return title
    }

    // MARK: - Multi-source Management

    private func updateSource(_ track: SystemNowPlaying) {
        let announce = Self.shouldAnnounce(existing: activeSources[track.sourceBundleId], incoming: track,
                                           currentSource: currentTrack?.sourceBundleId)

        activeSources[track.sourceBundleId] = track

        // Primary = most recently updated playing source
        if track.isPlaying {
            currentTrack = track
            isPlaying = true
        }

        if announce {
            print("[NowPlaying] 🎵 \(track.artist) — \(track.title) (via \(track.sourceAppName))")
            onTrackChange?(track)
        }
    }

    /// A new title on a source is a track change; so is a paused source starting again while another source
    /// is current (switching back to it), or the scrobbler keeps counting time against the other track.
    nonisolated static func shouldAnnounce(existing: SystemNowPlaying?, incoming: SystemNowPlaying,
                                           currentSource: String?) -> Bool {
        guard incoming.isPlaying else { return false }
        guard let existing else { return true }
        if existing.title != incoming.title || existing.artist != incoming.artist { return true }
        return !existing.isPlaying && currentSource != incoming.sourceBundleId
    }

    private func markPaused(_ bundleId: String) {
        guard var track = activeSources[bundleId] else { return }
        track = SystemNowPlaying(
            title: track.title, artist: track.artist, album: track.album,
            duration: track.duration, elapsed: track.elapsed, playbackRate: 0,
            artwork: track.artwork, sourceBundleId: track.sourceBundleId,
            sourceAppName: track.sourceAppName, timestamp: track.timestamp
        )
        activeSources[bundleId] = track

        // If this was the current track, find next playing source
        if currentTrack?.sourceBundleId == bundleId {
            if let nextPlaying = activeSources.values.first(where: { $0.isPlaying }) {
                currentTrack = nextPlaying
            } else {
                isPlaying = false
            }
        }
    }

    /// Remove sources that haven't updated in 30s
    private func cleanStaleSources() {
        let staleThreshold: TimeInterval = 30
        let now = Date()
        for (key, source) in activeSources {
            if !source.isPlaying && now.timeIntervalSince(source.timestamp) > staleThreshold {
                activeSources.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Spotify Artwork

    private func loadSpotifyArtwork() async -> PlatformImage? {
        let script = """
        tell application "Spotify"
            if player state is playing then
                return artwork url of current track
            end if
        end tell
        """
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil, let urlStr = result.stringValue, let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return PlatformImage(data: data)
    }

    // MARK: - Helpers

    func appName(for bundleId: String) -> String {
        if bundleId.isEmpty { return "Unknown" }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return bundleId.split(separator: ".").last.map(String.init) ?? bundleId
    }

    func appIcon(for bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    deinit { if let handle { dlclose(handle) } }
}
#endif
