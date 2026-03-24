import Foundation
import SwiftUI

/// Tracks all outgoing API calls — count, timing, errors, per-service breakdown.
@MainActor
class APITracker: ObservableObject {
    static let shared = APITracker()

    @Published var calls: [APICallRecord] = []
    @Published var serviceTotals: [String: ServiceStats] = [:]

    /// Record an API call
    func record(service: String, endpoint: String, duration: TimeInterval, success: Bool, statusCode: Int? = nil) {
        let record = APICallRecord(
            service: service,
            endpoint: endpoint,
            duration: duration,
            success: success,
            statusCode: statusCode,
            timestamp: Date()
        )

        calls.append(record)

        // Cap at 500 records
        if calls.count > 500 { calls = Array(calls.suffix(500)) }

        // Update service totals
        var stats = serviceTotals[service] ?? ServiceStats(service: service)
        stats.totalCalls += 1
        stats.totalDuration += duration
        if success { stats.successCount += 1 } else { stats.errorCount += 1 }
        stats.avgDuration = stats.totalDuration / Double(stats.totalCalls)
        if duration < stats.minDuration { stats.minDuration = duration }
        if duration > stats.maxDuration { stats.maxDuration = duration }
        stats.recentDurations.append(duration)
        if stats.recentDurations.count > 30 { stats.recentDurations.removeFirst() }
        serviceTotals[service] = stats
    }

    /// Convenience: wrap an async API call with automatic tracking
    func track<T>(service: String, endpoint: String, call: () async throws -> T) async throws -> T {
        let start = Date()
        do {
            let result = try await call()
            let duration = Date().timeIntervalSince(start)
            await MainActor.run {
                record(service: service, endpoint: endpoint, duration: duration, success: true)
            }
            return result
        } catch {
            let duration = Date().timeIntervalSince(start)
            await MainActor.run {
                record(service: service, endpoint: endpoint, duration: duration, success: false)
            }
            throw error
        }
    }

    var totalCalls: Int { serviceTotals.values.reduce(0) { $0 + $1.totalCalls } }
    var totalErrors: Int { serviceTotals.values.reduce(0) { $0 + $1.errorCount } }
    var errorRate: Double { totalCalls > 0 ? Double(totalErrors) / Double(totalCalls) * 100 : 0 }

    /// Services sorted by call count (most active first)
    var rankedServices: [ServiceStats] {
        serviceTotals.values.sorted { $0.totalCalls > $1.totalCalls }
    }

    func clear() {
        calls.removeAll()
        serviceTotals.removeAll()
    }
}

// MARK: - Tracked URL fetching

extension URLSession {
    /// Fetch data with automatic API tracking
    func trackedData(from url: URL, service: String) async throws -> (Data, URLResponse) {
        let endpoint = url.path.components(separatedBy: "/").last ?? url.host ?? "unknown"
        let start = Date()
        do {
            let (data, response) = try await self.data(from: url)
            let duration = Date().timeIntervalSince(start)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            await MainActor.run {
                APITracker.shared.record(service: service, endpoint: endpoint, duration: duration, success: true, statusCode: statusCode)
            }
            return (data, response)
        } catch {
            let duration = Date().timeIntervalSince(start)
            await MainActor.run {
                APITracker.shared.record(service: service, endpoint: endpoint, duration: duration, success: false)
            }
            throw error
        }
    }

    /// Fetch data for a request with tracking
    func trackedData(for request: URLRequest, service: String) async throws -> (Data, URLResponse) {
        let endpoint = request.url?.path.components(separatedBy: "/").last ?? "unknown"
        let start = Date()
        do {
            let (data, response) = try await self.data(for: request)
            let duration = Date().timeIntervalSince(start)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            await MainActor.run {
                APITracker.shared.record(service: service, endpoint: endpoint, duration: duration, success: true, statusCode: statusCode)
            }
            return (data, response)
        } catch {
            let duration = Date().timeIntervalSince(start)
            await MainActor.run {
                APITracker.shared.record(service: service, endpoint: endpoint, duration: duration, success: false)
            }
            throw error
        }
    }
}

struct APICallRecord: Identifiable {
    let id = UUID()
    let service: String
    let endpoint: String
    let duration: TimeInterval
    let success: Bool
    let statusCode: Int?
    let timestamp: Date

    var durationMs: Int { Int(duration * 1000) }
}

struct ServiceStats {
    let service: String
    var totalCalls: Int = 0
    var successCount: Int = 0
    var errorCount: Int = 0
    var totalDuration: TimeInterval = 0
    var avgDuration: TimeInterval = 0
    var minDuration: TimeInterval = .infinity
    var maxDuration: TimeInterval = 0
    var recentDurations: [TimeInterval] = []

    var avgMs: Int { Int(avgDuration * 1000) }
    var minMs: Int { minDuration == .infinity ? 0 : Int(minDuration * 1000) }
    var maxMs: Int { Int(maxDuration * 1000) }
    var successRate: Double { totalCalls > 0 ? Double(successCount) / Double(totalCalls) * 100 : 0 }

    var color: Color {
        switch service {
        case "Last.fm": return .red
        case "Discogs": return .teal
        case "MusicBrainz": return .purple
        case "iTunes": return .pink
        case "Wikidata": return .blue
        case "YouTube Music": return .orange
        default: return .gray
        }
    }
}
