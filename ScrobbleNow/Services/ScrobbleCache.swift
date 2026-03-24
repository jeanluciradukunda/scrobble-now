import Foundation

/// Persists pending scrobbles and retries failed ones.
/// Stores successful/failed history for the cache view in settings.
actor ScrobbleCache {
    static let shared = ScrobbleCache()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var storeDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ScrobbleNow", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var pendingFile: URL { storeDirectory.appendingPathComponent("pending_scrobbles.json") }
    private var historyFile: URL { storeDirectory.appendingPathComponent("scrobble_history.json") }

    // MARK: - Queue a failed scrobble for retry

    func queueForRetry(_ entry: ScrobbleCacheEntry) {
        var pending = loadPending()
        pending.append(entry)
        // Cap at 500 pending
        if pending.count > 500 { pending = Array(pending.suffix(500)) }
        savePending(pending)
    }

    // MARK: - Retry all pending scrobbles

    func retryPending(using lastfm: LastFMService) async -> (succeeded: Int, failed: Int) {
        var pending = loadPending()
        guard !pending.isEmpty else { return (0, 0) }

        var succeeded = 0
        var stillFailed: [ScrobbleCacheEntry] = []

        for entry in pending {
            do {
                try await lastfm.scrobble(
                    artist: entry.artist,
                    track: entry.track,
                    album: entry.album,
                    timestamp: entry.timestamp
                )
                succeeded += 1
                logHistory(entry, success: true)
            } catch {
                var failed = entry
                failed.retryCount += 1
                // Give up after 10 retries
                if failed.retryCount < 10 {
                    stillFailed.append(failed)
                } else {
                    logHistory(failed, success: false)
                }
            }
            // Small delay between retries to not hammer the API
            try? await Task.sleep(for: .milliseconds(200))
        }

        savePending(stillFailed)
        return (succeeded, stillFailed.count)
    }

    // MARK: - Log to history

    func logHistory(_ entry: ScrobbleCacheEntry, success: Bool) {
        var history = loadHistory()
        var logged = entry
        logged.succeeded = success
        logged.scrobbledAt = Date()
        history.append(logged)
        // Keep last 1000
        if history.count > 1000 { history = Array(history.suffix(1000)) }
        saveHistory(history)
    }

    func logSuccess(artist: String, track: String, album: String, timestamp: Int) {
        let entry = ScrobbleCacheEntry(
            artist: artist, track: track, album: album,
            timestamp: timestamp, succeeded: true, scrobbledAt: Date()
        )
        logHistory(entry, success: true)
    }

    // MARK: - Stats

    func pendingCount() -> Int { loadPending().count }
    func historyCount() -> Int { loadHistory().count }
    func successCount() -> Int { loadHistory().filter { $0.succeeded == true }.count }
    func failedCount() -> Int { loadHistory().filter { $0.succeeded == false }.count }

    // MARK: - Clear

    func clearPending() { savePending([]) }
    func clearHistory() { saveHistory([]) }

    // MARK: - Persistence

    private func loadPending() -> [ScrobbleCacheEntry] {
        guard let data = try? Data(contentsOf: pendingFile),
              let entries = try? decoder.decode([ScrobbleCacheEntry].self, from: data) else { return [] }
        return entries
    }

    private func savePending(_ entries: [ScrobbleCacheEntry]) {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: pendingFile, options: .atomic)
    }

    private func loadHistory() -> [ScrobbleCacheEntry] {
        guard let data = try? Data(contentsOf: historyFile),
              let entries = try? decoder.decode([ScrobbleCacheEntry].self, from: data) else { return [] }
        return entries
    }

    private func saveHistory(_ entries: [ScrobbleCacheEntry]) {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: historyFile, options: .atomic)
    }
}

// MARK: - Cache Entry

struct ScrobbleCacheEntry: Codable, Identifiable {
    var id: String { "\(artist)|\(track)|\(timestamp)" }
    let artist: String
    let track: String
    let album: String
    let timestamp: Int
    var retryCount: Int = 0
    var succeeded: Bool?
    var scrobbledAt: Date?
}
