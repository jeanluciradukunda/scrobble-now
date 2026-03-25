#if os(iOS)
import Foundation
import MediaPlayer

/// iOS Now Playing detection via MPNowPlayingInfoCenter.
@MainActor
class MPNowPlayingBridge: ObservableObject {
    static let shared = MPNowPlayingBridge()

    @Published var activeSources: [String: SystemNowPlaying] = [:]
    @Published var currentTrack: SystemNowPlaying?
    @Published var isPlaying: Bool = false

    var onTrackChange: ((SystemNowPlaying?) -> Void)?

    private var pollTimer: Timer?
    private var isListening = false
    private var cachedArtwork: PlatformImage?
    private var cachedArtworkTrackKey: String?

    private init() {}

    func startListening() {
        guard !isListening else { return }
        isListening = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: nil
        )

        MPMusicPlayerController.systemMusicPlayer.beginGeneratingPlaybackNotifications()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollNowPlaying()
            }
        }

        pollNowPlaying()
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        MPMusicPlayerController.systemMusicPlayer.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func nowPlayingChanged() {
        cachedArtwork = nil
        cachedArtworkTrackKey = nil
        pollNowPlaying()
    }

    @objc private func playbackStateChanged() {
        pollNowPlaying()
    }

    private func pollNowPlaying() {
        let player = MPMusicPlayerController.systemMusicPlayer
        guard let item = player.nowPlayingItem else {
            if isPlaying {
                isPlaying = false
            }
            return
        }

        let title = item.title ?? ""
        guard !title.isEmpty else { return }

        let artist = item.artist ?? ""
        let album = item.albumTitle ?? ""
        let duration = item.playbackDuration
        let elapsed = player.currentPlaybackTime
        let rate: Double = player.playbackState == .playing ? 1.0 : 0.0
        let trackKey = "\(artist)|\(title)"

        // Only re-render artwork when the track changes
        if trackKey != cachedArtworkTrackKey {
            cachedArtworkTrackKey = trackKey
            cachedArtwork = item.artwork?.image(at: CGSize(width: 300, height: 300))
        }

        let bundleId = "com.apple.Music"
        let track = SystemNowPlaying(
            title: title, artist: artist, album: album,
            duration: duration, elapsed: elapsed, playbackRate: rate,
            artwork: cachedArtwork, sourceBundleId: bundleId,
            sourceAppName: "Music", timestamp: Date()
        )

        let isNew = currentTrack?.title != track.title || currentTrack?.artist != track.artist
        let playingChanged = isPlaying != (rate > 0)

        // Only update @Published properties when something actually changed
        if isNew || playingChanged || (rate > 0 && currentTrack?.elapsed != track.elapsed) {
            activeSources[bundleId] = track
            currentTrack = track
        }

        if playingChanged {
            isPlaying = rate > 0
        }

        if isNew && track.isPlaying {
            onTrackChange?(track)
        }
    }
}
#endif
