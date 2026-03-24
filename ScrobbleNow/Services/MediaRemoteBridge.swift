import Foundation
import AppKit

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

    private var pollTimer: Timer?

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

        // Fast poll for MediaRemote (1s) — lightweight
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollMediaRemote()
                self?.cleanStaleSources()
            }
        }

        // Slower poll for browsers (3s) — heavier osascript calls
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollBrowsers()
            }
        }

        pollMediaRemote()
        pollBrowsers()
        print("[NowPlaying] ✓ Listening (Spotify + Music + MediaRemote + Browser polling)")
    }

    func stopListening() {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        pollTimer?.invalidate()
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

        var track = SystemNowPlaying(
            title: title, artist: artist, album: album,
            duration: duration, elapsed: 0, playbackRate: 1.0,
            artwork: nil, sourceBundleId: "com.spotify.client",
            sourceAppName: "Spotify", timestamp: Date()
        )

        // Load artwork async
        Task {
            if let artwork = await loadSpotifyArtwork() {
                track = track.withArtwork(artwork)
            }
            self.updateSource(track)
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

    // MARK: - Browser Polling (Chrome, Safari, Arc, etc.)

    var lastBrowserTitle: String = ""
    private var previousBrowserTabs: Set<String> = []

    /// Polls Chrome/Safari/Arc for music tab titles
    private func pollBrowsers() {
        // Run browser polling off main thread
        Task.detached { [weak self] in
            await self?.pollBrowserAsync()
        }
    }

    private func pollBrowserAsync() async {
        // Check Chrome — return ALL music tabs, not just the first
        await pollBrowser(
            appName: "Google Chrome",
            bundleId: "com.google.Chrome",
            scriptTemplate: """
            tell application "Google Chrome"
                set output to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabURL to URL of t
                        set tabTitle to title of t
                        if tabURL contains "youtube.com" or tabURL contains "soundcloud.com" or tabURL contains "bandcamp.com" or tabURL contains "open.spotify.com" or tabURL contains "tidal.com" or tabURL contains "deezer.com" or tabURL contains "music.apple.com" then
                            set output to output & tabURL & "|||" & tabTitle & "###"
                        end if
                    end repeat
                end repeat
            end tell
            return output
            """
        )

        // Check Safari
        await pollBrowser(
            appName: "Safari",
            bundleId: "com.apple.Safari",
            scriptTemplate: """
            tell application "Safari"
                set output to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabURL to URL of t
                        set tabTitle to name of t
                        if tabURL contains "youtube.com" or tabURL contains "soundcloud.com" or tabURL contains "bandcamp.com" or tabURL contains "open.spotify.com" or tabURL contains "tidal.com" or tabURL contains "deezer.com" or tabURL contains "music.apple.com" then
                            set output to output & tabURL & "|||" & tabTitle & "###"
                        end if
                    end repeat
                end repeat
            end tell
            return output
            """
        )
    }

    private func pollBrowser(appName: String, bundleId: String, scriptTemplate: String) async {
        // Only poll if the browser is running
        let isRunning = await MainActor.run {
            NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleId })
        }
        guard isRunning else { return }

        // Run osascript with a 2-second timeout to prevent blocking
        let raw: String? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", scriptTemplate]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                // Timeout after 2 seconds
                let deadline = DispatchTime.now() + 2.0
                DispatchQueue.global().asyncAfter(deadline: deadline) {
                    if process.isRunning {
                        process.terminate()
                    }
                }

                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: result)
            }
        }

        guard let raw, !raw.isEmpty else {
            // No music tabs found — mark browser source as paused
            markPaused(bundleId)
            return
        }

        // Parse ALL music tabs (separated by ###)
        let allTabs = raw.components(separatedBy: "###")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { entry -> (url: String, title: String)? in
                let parts = entry.components(separatedBy: "|||")
                guard parts.count == 2 else { return nil }
                return (parts[0], parts[1])
            }

        guard !allTabs.isEmpty else {
            markPaused(bundleId)
            return
        }

        // Build current tab signature set
        let currentKeys = Set(allTabs.map { $0.title })

        // Find NEW tabs (titles not seen in previous poll) — these just started playing
        var newTabs = allTabs.filter { !previousBrowserTabs.contains($0.title) }

        // If no new tabs, check if any existing tab's title changed (track change within same tab)
        if newTabs.isEmpty {
            newTabs = allTabs.filter { "\(bundleId):\($0.title)" != lastBrowserTitle }
        }

        previousBrowserTabs = currentKeys

        // Process the newest changed tab (or first tab if nothing changed)
        let activeTab = newTabs.first ?? allTabs[0]
        let url = activeTab.url
        let title = activeTab.title

        // Skip if same as last processed
        let key = "\(bundleId):\(title)"
        guard key != lastBrowserTitle else { return }
        lastBrowserTitle = key

        // YouTube: check if it's actually music before scrobbling
        if url.contains("youtube.com") {
            if let videoId = YouTubeMusicFilter.extractVideoId(from: url) {
                let result = await YouTubeMusicFilter.shared.check(videoId: videoId)
                guard result.isMusic else {
                    print("[Browser] ⏭ Skipping non-music YouTube: \(title.prefix(50))")
                    return
                }
                // If YouTube Music API gave us artist/track, fetch proper album art from Last.fm
                if let ytArtist = result.artist, let ytTrack = result.track {
                    var artwork: NSImage?
                    var albumName = result.album ?? ""

                    // Try Last.fm track.getInfo for album art
                    let apiKey = KeychainService.lastfmApiKey
                    if !apiKey.isEmpty {
                        let artistEnc = ytArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        let trackEnc = ytTrack.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

                        // Try track.getInfo first — gives us album name + artwork
                        if let trackURL = URL(string: "https://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=\(apiKey)&artist=\(artistEnc)&track=\(trackEnc)&format=json"),
                           let (trackData, _) = try? await URLSession.shared.trackedData(from: trackURL, service: "Last.fm"),
                           let trackJson = try? JSONSerialization.jsonObject(with: trackData) as? [String: Any],
                           let trackInfo = trackJson["track"] as? [String: Any] {

                            // Get album name
                            if let album = trackInfo["album"] as? [String: Any],
                               let name = album["title"] as? String {
                                albumName = name

                                // Get album artwork
                                if let images = album["image"] as? [[String: Any]] {
                                    for size in ["extralarge", "large", "medium"] {
                                        if let img = images.first(where: { ($0["size"] as? String) == size }),
                                           let urlStr = img["#text"] as? String, !urlStr.isEmpty,
                                           let imgURL = URL(string: urlStr),
                                           let (imgData, _) = try? await URLSession.shared.data(from: imgURL) {
                                            artwork = NSImage(data: imgData)
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Fallback: YouTube video thumbnail if no Last.fm art
                    if artwork == nil {
                        let thumbURL = URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")!
                        if let (imgData, _) = try? await URLSession.shared.data(from: thumbURL) {
                            artwork = NSImage(data: imgData)
                        }
                    }

                    let track = SystemNowPlaying(
                        title: ytTrack, artist: ytArtist, album: albumName,
                        duration: result.durationSeconds ?? 0, elapsed: 0, playbackRate: 1.0,
                        artwork: artwork, sourceBundleId: bundleId,
                        sourceAppName: "\(appName) · YouTube", timestamp: Date()
                    )
                    await MainActor.run { updateSource(track) }
                    return
                }
            }
        }

        // Parse track info from tab title
        let parsed = parseTabTitle(title, url: url)
        guard !parsed.title.isEmpty else { return }

        let track = SystemNowPlaying(
            title: parsed.title, artist: parsed.artist, album: "",
            duration: 0, elapsed: 0, playbackRate: 1.0,
            artwork: nil, sourceBundleId: bundleId,
            sourceAppName: "\(appName) · \(parsed.service)", timestamp: Date()
        )

        await MainActor.run { updateSource(track) }
    }

    private struct ParsedTab {
        let title: String
        let artist: String
        let service: String
    }

    private func parseTabTitle(_ title: String, url: String) -> ParsedTab {
        // YouTube Music: "Song Title - Artist - YouTube Music"
        if url.contains("music.youtube.com") {
            let cleaned = title.replacingOccurrences(of: " - YouTube Music", with: "")
            let parts = cleaned.components(separatedBy: " - ")
            if parts.count >= 2 {
                return ParsedTab(title: parts[0].trimmingCharacters(in: .whitespaces),
                                 artist: parts[1].trimmingCharacters(in: .whitespaces),
                                 service: "YouTube Music")
            }
            return ParsedTab(title: cleaned, artist: "", service: "YouTube Music")
        }

        // YouTube (regular): "Song Title - Artist - YouTube" or "Video Title - YouTube"
        if url.contains("youtube.com") {
            let cleaned = title.replacingOccurrences(of: " - YouTube", with: "")
            let parts = cleaned.components(separatedBy: " - ")
            if parts.count >= 2 {
                // Could be "Artist - Song" or "Song - Artist" — try both
                return ParsedTab(title: parts[0].trimmingCharacters(in: .whitespaces),
                                 artist: parts[1].trimmingCharacters(in: .whitespaces),
                                 service: "YouTube")
            }
            // Single title — use as track name, no artist
            return ParsedTab(title: cleaned.trimmingCharacters(in: .whitespaces),
                             artist: "", service: "YouTube")
        }

        // SoundCloud: "Stream Artist - Song Title | Listen online..."
        if url.contains("soundcloud.com") {
            let cleaned = title.replacingOccurrences(of: "Stream ", with: "")
                .components(separatedBy: " | ").first ?? title
            let parts = cleaned.components(separatedBy: " - ")
            if parts.count >= 2 {
                return ParsedTab(title: parts[1].trimmingCharacters(in: .whitespaces),
                                 artist: parts[0].trimmingCharacters(in: .whitespaces),
                                 service: "SoundCloud")
            }
            return ParsedTab(title: cleaned, artist: "", service: "SoundCloud")
        }

        // Bandcamp: "Song Title | Artist"
        if url.contains("bandcamp.com") {
            let parts = title.components(separatedBy: " | ")
            if parts.count >= 2 {
                return ParsedTab(title: parts[0].trimmingCharacters(in: .whitespaces),
                                 artist: parts[1].trimmingCharacters(in: .whitespaces),
                                 service: "Bandcamp")
            }
        }

        // Spotify Web: "Song Title - song and target by Artist | Spotify"
        if url.contains("open.spotify.com") {
            let cleaned = title.components(separatedBy: " | ").first ?? title
            let parts = cleaned.components(separatedBy: " - song")
            if let songTitle = parts.first {
                // Try to extract artist from "and lyrics by Artist"
                if cleaned.contains(" by "), let byPart = cleaned.components(separatedBy: " by ").last {
                    return ParsedTab(title: songTitle.trimmingCharacters(in: .whitespaces),
                                     artist: byPart.trimmingCharacters(in: .whitespaces),
                                     service: "Spotify Web")
                }
                return ParsedTab(title: songTitle.trimmingCharacters(in: .whitespaces), artist: "", service: "Spotify Web")
            }
        }

        // Tidal: "Song Title - Artist - Tidal"
        if url.contains("tidal.com") {
            let parts = title.components(separatedBy: " - ")
            if parts.count >= 2 {
                return ParsedTab(title: parts[0].trimmingCharacters(in: .whitespaces),
                                 artist: parts[1].trimmingCharacters(in: .whitespaces),
                                 service: "Tidal")
            }
        }

        // Generic fallback
        return ParsedTab(title: title, artist: "", service: "Browser")
    }

    // MARK: - MediaRemote (fallback for other apps)

    @objc private func mediaRemoteChanged(_ notification: Notification) {
        pollMediaRemote()
    }

    func pollMediaRemote() {
        guard let getInfo = _getNowPlayingInfo else { return }

        getInfo(DispatchQueue.main) { [weak self] cfDict in
            let info = cfDict as NSDictionary as! [String: Any]
            Task { @MainActor in
                self?.processMediaRemoteInfo(info)
            }
        }
    }

    private var hasLoggedKeys = false

    private func processMediaRemoteInfo(_ info: [String: Any]) {
        guard !info.isEmpty else { return }

        if !hasLoggedKeys {
            hasLoggedKeys = true
            print("[MediaRemote] ✓ Got data! Keys: \(info.keys.sorted().joined(separator: ", "))")
            for (k, v) in info.sorted(by: { $0.key < $1.key }) {
                if v is Data {
                    print("[MediaRemote]   \(k) = <Data \((v as! Data).count) bytes>")
                } else {
                    print("[MediaRemote]   \(k) = \(String(describing: v).prefix(80))")
                }
            }
        }

        let rawTitle = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
        guard !rawTitle.isEmpty else { return }

        var artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
        var title = rawTitle
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

        // If title looks like "Artist - Track (official video)" and we have a separate artist field,
        // the title might contain redundant artist info — clean it up
        if !artist.isEmpty && title.lowercased().hasPrefix(artist.lowercased()) {
            // Title is "Artist - Actual Track Name..." — extract just the track
            let afterArtist = title.dropFirst(artist.count)
            let separators = [" - ", " – ", " — "]
            for sep in separators {
                if afterArtist.hasPrefix(sep) {
                    title = String(afterArtist.dropFirst(sep.count))
                    break
                }
            }
        }

        // Strip common YouTube suffixes
        for suffix in [" (official video)", " (official audio)", " (official music video)",
                       " (lyric video)", " (lyrics)", " (audio)", " (visualizer)", " (mv)"] {
            if title.lowercased().hasSuffix(suffix) {
                title = String(title.dropLast(suffix.count))
            }
        }

        var artwork: NSImage?
        if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, !data.isEmpty {
            artwork = NSImage(data: data)
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

    // MARK: - Multi-source Management

    private func updateSource(_ track: SystemNowPlaying) {
        let isNew = activeSources[track.sourceBundleId]?.title != track.title
                 || activeSources[track.sourceBundleId]?.artist != track.artist

        activeSources[track.sourceBundleId] = track

        // Primary = most recently updated playing source
        if track.isPlaying {
            currentTrack = track
            isPlaying = true
        }

        if isNew && track.isPlaying {
            print("[NowPlaying] 🎵 \(track.artist) — \(track.title) (via \(track.sourceAppName))")
            onTrackChange?(track)
        }
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

    private func loadSpotifyArtwork() async -> NSImage? {
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
        return NSImage(data: data)
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

// MARK: - Data Model

struct SystemNowPlaying: Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let elapsed: Double
    let playbackRate: Double
    let artwork: NSImage?
    let sourceBundleId: String
    let sourceAppName: String
    let timestamp: Date

    var isPlaying: Bool { playbackRate > 0 }
    var progress: Double { duration > 0 ? min(1, elapsed / duration) : 0 }
    var elapsedFormatted: String { formatTime(elapsed) }
    var durationFormatted: String { formatTime(duration) }
    var remainingFormatted: String { formatTime(max(0, duration - elapsed)) }

    func withArtwork(_ img: NSImage) -> SystemNowPlaying {
        SystemNowPlaying(title: title, artist: artist, album: album,
                         duration: duration, elapsed: elapsed, playbackRate: playbackRate,
                         artwork: img, sourceBundleId: sourceBundleId,
                         sourceAppName: sourceAppName, timestamp: timestamp)
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60; let s = Int(seconds) % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    static func == (lhs: SystemNowPlaying, rhs: SystemNowPlaying) -> Bool {
        lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.sourceBundleId == rhs.sourceBundleId
    }
}
