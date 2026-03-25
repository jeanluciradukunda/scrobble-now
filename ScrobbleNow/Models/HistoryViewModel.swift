import SwiftUI

// MARK: - Listening Session

struct ListeningSession: Identifiable {
    // tracks are sorted newest → oldest
    let tracks: [ScrobbledTrack]

    var id: String {
        "\(Int(startTime.timeIntervalSince1970))-\(Int(endTime.timeIntervalSince1970))"
    }

    // oldest track = session start, newest = session end
    var startTime: Date { tracks.last?.timestamp  ?? Date() }
    var endTime:   Date { tracks.first?.timestamp ?? Date() }

    var trackCount: Int { tracks.count }

    var timeLabel: String {
        let h = Calendar.current.component(.hour, from: startTime)
        switch h {
        case 5..<9:   return "Early Morning"
        case 9..<12:  return "Morning"
        case 12..<14: return "Lunchtime"
        case 14..<17: return "Afternoon"
        case 17..<20: return "Evening"
        case 20..<23: return "Night"
        default:      return "Late Night"
        }
    }

    var icon: String {
        let h = Calendar.current.component(.hour, from: startTime)
        switch h {
        case 5..<8:   return "sunrise.fill"
        case 8..<12:  return "sun.max.fill"
        case 12..<14: return "fork.knife"
        case 14..<17: return "sun.haze.fill"
        case 17..<20: return "sunset.fill"
        case 20..<23: return "moon.stars.fill"
        default:      return "moon.fill"
        }
    }

    var timeRangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        if Calendar.current.isDate(startTime, inSameDayAs: endTime) {
            return "\(f.string(from: startTime)) – \(f.string(from: endTime))"
        }
        return f.string(from: startTime)
    }

    var topArtist: String? {
        Dictionary(grouping: tracks, by: { $0.artistName })
            .max(by: { $0.value.count < $1.value.count })?.key
    }

    var topArtworkURL: URL? {
        Dictionary(grouping: tracks, by: { $0.albumName })
            .max(by: { $0.value.count < $1.value.count })?
            .value.first?.albumArtworkURL
    }
}

// MARK: - DayGroup

struct DayGroup: Identifiable {
    let id: String  // "2026-03-23"
    let date: Date
    let tracks: [ScrobbledTrack]

    var displayDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    var totalScrobbles: Int { tracks.count }
    var uniqueArtists:  Int { Set(tracks.map { $0.artistName.lowercased() }).count }
    var uniqueAlbums:   Int { Set(tracks.map { $0.albumName.lowercased()  }).count }

    var topArtist: String? {
        Dictionary(grouping: tracks, by: { $0.artistName })
            .max(by: { $0.value.count < $1.value.count })?.key
    }

    var topArtworkURL: URL? {
        Dictionary(grouping: tracks, by: { $0.albumName })
            .max(by: { $0.value.count < $1.value.count })?
            .value.first?.albumArtworkURL
    }

    var listeningSpan: String? {
        guard let first = tracks.last?.timestamp,
              let last  = tracks.first?.timestamp else { return nil }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }

    /// Cluster tracks into sessions (gap > 30 min = new session).
    var sessions: [ListeningSession] {
        guard !tracks.isEmpty else { return [] }
        let gapThreshold: TimeInterval = 30 * 60

        var groups: [[ScrobbledTrack]] = []
        var current: [ScrobbledTrack]  = [tracks[0]]

        for i in 1..<tracks.count {
            let gap = tracks[i-1].timestamp.timeIntervalSince(tracks[i].timestamp)
            if gap > gapThreshold {
                groups.append(current)
                current = [tracks[i]]
            } else {
                current.append(tracks[i])
            }
        }
        groups.append(current)
        return groups.map { ListeningSession(tracks: $0) }
    }
}

// MARK: - HistoryViewModel

@MainActor
class HistoryViewModel: ObservableObject {

    enum ViewMode: String, CaseIterable, Hashable {
        case timeline = "Timeline"
        case calendar = "Calendar"
    }

    @Published var dayGroups:         [DayGroup]   = []
    @Published var isLoading                        = false
    @Published var errorMessage:      String?       = nil
    @Published var viewMode:          ViewMode      = .timeline
    @Published var calendarMonth:     Date          = Calendar.current.startOfMonth(for: Date())
    @Published var selectedDay:       DayGroup?     = nil
    @Published var daysWithScrobbles: Set<String>   = []
    @Published var isLoadingDay                     = false

    private let lastfm = LastFMService()

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    // MARK: Streak

    var streak: Int {
        let cal = Calendar.current
        var check   = cal.startOfDay(for: Date())
        var count   = 0
        let todayKey = Self.dayFmt.string(from: check)

        // If nothing today, start checking from yesterday
        if !daysWithScrobbles.contains(todayKey) {
            check = cal.date(byAdding: .day, value: -1, to: check)!
        }
        while daysWithScrobbles.contains(Self.dayFmt.string(from: check)) {
            count += 1
            check = cal.date(byAdding: .day, value: -1, to: check)!
            if count > 365 { break }
        }
        return count
    }

    // MARK: Initial load

    func load() async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else { errorMessage = "No username set"; return }

        isLoading = dayGroups.isEmpty
        defer { isLoading = false }
        do {
            let tracks = try await lastfm.getRecentTracks(user: username, limit: 200)
            let groups = Self.group(tracks.filter { !$0.isNowPlaying })
            dayGroups         = groups
            daysWithScrobbles = Set(groups.map { $0.id })
            errorMessage      = nil
        } catch {
            if dayGroups.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    // MARK: Calendar month load

    func goToMonth(_ month: Date) {
        calendarMonth = month
        Task { await loadMonth(month) }
    }

    func loadMonth(_ month: Date) async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else { return }

        let cal   = Calendar.current
        let start = cal.startOfMonth(for: month)
        let end   = cal.date(byAdding: .month, value: 1, to: start)!

        isLoading = true
        defer { isLoading = false }
        do {
            let tracks = try await lastfm.getRecentTracks(
                user: username, limit: 1000, from: start, to: end
            )
            let groups = Self.group(tracks.filter { !$0.isNowPlaying })
            var byId   = Dictionary(uniqueKeysWithValues: dayGroups.map { ($0.id, $0) })
            for g in groups { byId[g.id] = g }
            dayGroups         = byId.values.sorted { $0.date > $1.date }
            daysWithScrobbles = Set(dayGroups.map { $0.id })
        } catch {}
    }

    // MARK: Day load

    func loadDay(_ date: Date) async {
        let key = Self.dayFmt.string(from: date)
        if let existing = dayGroups.first(where: { $0.id == key }) {
            withAnimation(.spring(duration: 0.38, bounce: 0.1)) { selectedDay = existing }
            return
        }

        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else { return }

        isLoadingDay = true
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!

        do {
            let tracks = try await lastfm.getRecentTracks(
                user: username, limit: 200, from: start, to: end
            )
            let groups = Self.group(tracks.filter { !$0.isNowPlaying })
            let result = groups.first(where: { $0.id == key })
                ?? DayGroup(id: key, date: date, tracks: [])

            var byId = Dictionary(uniqueKeysWithValues: dayGroups.map { ($0.id, $0) })
            byId[key] = result
            dayGroups         = byId.values.sorted { $0.date > $1.date }
            daysWithScrobbles = Set(dayGroups.map { $0.id })

            withAnimation(.spring(duration: 0.38, bounce: 0.1)) { selectedDay = result }
        } catch {
            withAnimation(.spring(duration: 0.38, bounce: 0.1)) {
                selectedDay = DayGroup(id: key, date: date, tracks: [])
            }
        }
        isLoadingDay = false
    }

    // MARK: Helpers

    private static func group(_ tracks: [ScrobbledTrack]) -> [DayGroup] {
        var grouped: [String: [ScrobbledTrack]] = [:]
        for t in tracks {
            let key = dayFmt.string(from: t.timestamp)
            grouped[key, default: []].append(t)
        }
        return grouped.map { key, ts in
            DayGroup(id: key, date: dayFmt.date(from: key) ?? Date(), tracks: ts)
        }
        .sorted { $0.date > $1.date }
    }
}

// MARK: - Calendar extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let c = dateComponents([.year, .month], from: date)
        return self.date(from: c) ?? date
    }
}
