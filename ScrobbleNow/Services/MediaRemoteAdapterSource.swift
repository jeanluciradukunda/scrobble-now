#if os(macOS)
import AppKit
import Foundation

enum AdapterStatus: Equatable {
    case off, starting, running, unavailable
}

enum AdapterUpdate: Equatable {
    case track(SystemNowPlaying)
    case nothingPlaying
}

/// Runs the vendored mediaremote-adapter (Vendor/MediaRemoteAdapter) under /usr/bin/perl, which macOS 15.4+
/// still allows to read system now-playing, and turns its JSON lines into tracks.
@MainActor
final class MediaRemoteAdapterSource {
    var onUpdate: ((AdapterUpdate) -> Void)?
    var onStatusChange: ((AdapterStatus) -> Void)?
    var appName: (String) -> String = { $0 }

    private(set) var status: AdapterStatus = .off {
        didSet { if status != oldValue { onStatusChange?(status) } }
    }

    private var process: Process?
    /// Bumped by every start and stop, so a test or backoff task from an earlier start cannot launch a stream.
    private var generation = 0
    private var quickFailures = 0
    private var startedAt = Date.distantPast
    private var terminationObserver: NSObjectProtocol?

    private static let maxQuickFailures = 5

    func start() {
        guard status == .off || status == .unavailable else { return }
        guard let paths = Paths() else {
            status = .unavailable
            return
        }
        generation += 1
        let gen = generation
        quickFailures = 0
        status = .starting
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
        Task {
            let passed = await Self.runTest(paths)
            guard gen == generation else { return }
            if passed {
                launchStream(paths, generation: gen)
            } else {
                status = .unavailable
            }
        }
    }

    func stop() {
        generation += 1
        process?.terminate()
        process = nil
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        terminationObserver = nil
        status = .off
    }

    private func launchStream(_ paths: Paths, generation gen: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        // Artwork is several hundred KB of base64 per line; the scrobbler already fetches artwork from Last.fm.
        process.arguments = paths.arguments(["stream", "--no-diff", "--debounce=200", "--no-artwork"])
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        let lines = LineBuffer()
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            for line in lines.append(data) {
                let now = Date()
                Task { @MainActor in
                    guard let self, gen == self.generation,
                          let update = Self.parse(line: line, now: now, appName: self.appName) else { return }
                    self.onUpdate?(update)
                }
            }
        }
        process.terminationHandler = { [weak self] ended in
            Task { @MainActor in self?.streamEnded(paths, generation: gen, process: ended) }
        }

        do {
            try process.run()
            self.process = process
            startedAt = Date()
            status = .running
        } catch {
            status = .unavailable
        }
    }

    private func streamEnded(_ paths: Paths, generation gen: Int, process ended: Process) {
        guard gen == generation, ended === process else { return }
        process = nil
        if Date().timeIntervalSince(startedAt) < 10 {
            quickFailures += 1
        } else {
            quickFailures = 0
        }
        guard quickFailures < Self.maxQuickFailures else {
            status = .unavailable
            return
        }
        status = .starting
        let delay = min(60, pow(2, Double(quickFailures)))
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard gen == generation else { return }
            launchStream(paths, generation: gen)
        }
    }

    private nonisolated static func runTest(_ paths: Paths) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = paths.arguments(["test"])
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus == 0) }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    private struct Paths: Sendable {
        let script: String
        let framework: String
        let testClient: String

        init?() {
            guard let script = Bundle.main.path(forResource: "mediaremote-adapter", ofType: "pl"),
                  let frameworks = Bundle.main.privateFrameworksPath,
                  let testClient = Bundle.main.path(forAuxiliaryExecutable: "MediaRemoteAdapterTestClient")
            else { return nil }
            let framework = frameworks + "/MediaRemoteAdapter.framework"
            guard FileManager.default.fileExists(atPath: framework) else { return nil }
            self.script = script
            self.framework = framework
            self.testClient = testClient
        }

        func arguments(_ command: [String]) -> [String] {
            [script, framework, testClient] + command
        }
    }
}

private final class LineBuffer: @unchecked Sendable {
    private var pending = Data()
    private let lock = NSLock()

    func append(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            let line = pending[pending.startIndex..<newline]
            pending.removeSubrange(pending.startIndex...newline)
            if let text = String(data: line, encoding: .utf8), !text.isEmpty { lines.append(text) }
        }
        return lines
    }
}

extension MediaRemoteAdapterSource {
    /// Maps one `stream --no-diff` line to an update; nil for lines that carry nothing usable.
    nonisolated static func parse(line: String, now: Date, appName: (String) -> String) -> AdapterUpdate? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              object["type"] as? String == "data",
              let payload = object["payload"] as? [String: Any] else { return nil }
        guard let title = payload["title"] as? String, !title.isEmpty else { return .nothingPlaying }

        let artist = payload["artist"] as? String ?? ""
        let contentId = payload["contentItemIdentifier"] as? String ?? ""
        // Music's end-of-queue "AutoPlay" placeholder and untagged items are not scrobblable tracks.
        if artist.isEmpty || contentId.hasPrefix("PLACEHOLDER=") { return .nothingPlaying }

        let playing = payload["playing"] as? Bool ?? false
        let reportedRate = payload["playbackRate"] as? Double ?? 0
        // `playing` changes before `playbackRate` does, so it decides the state.
        let rate = playing ? (reportedRate > 0 ? reportedRate : 1) : 0

        var duration = payload["duration"] as? Double ?? 0
        if !duration.isFinite || duration < 0 { duration = 0 }

        var elapsed = payload["elapsedTime"] as? Double ?? 0
        // The timestamp only moves with playbackRate; with a stale one (Music sends days-old values while
        // `playing` flips) extrapolating would jump to the end of the track and scrobble at once.
        if playing, reportedRate > 0, let stamp = payload["timestamp"] as? String,
           let stampDate = ISO8601DateFormatter().date(from: stamp) {
            let age = now.timeIntervalSince(stampDate)
            if age > 0, age < 600 { elapsed += age * reportedRate }
        }
        if duration > 0 { elapsed = min(elapsed, duration) }

        let bundleId = payload["parentApplicationBundleIdentifier"] as? String
            ?? payload["bundleIdentifier"] as? String
            ?? "system"

        return .track(SystemNowPlaying(
            title: MediaRemoteBridge.cleanedTitle(title, artist: artist), artist: artist,
            album: payload["album"] as? String ?? "",
            duration: duration, elapsed: max(0, elapsed), playbackRate: rate, artwork: nil,
            sourceBundleId: bundleId, sourceAppName: appName(bundleId), timestamp: now
        ))
    }
}
#endif
