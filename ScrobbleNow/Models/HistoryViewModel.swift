import SwiftUI

// MARK: - DayGroup

struct DayGroup: Identifiable {
    let id: String  // "2026-03-23"
    let date: Date
    let tracks: [ScrobbledTrack]

    var displayDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var totalScrobbles: Int { tracks.count }
    var uniqueArtists: Int { Set(tracks.map { $0.artistName.lowercased() }).count }
    var uniqueAlbums: Int  { Set(tracks.map { $0.albumName.lowercased() }).count }
}

// MARK: - HistoryViewModel

@MainActor
class HistoryViewModel: ObservableObject {

    enum ViewMode: String, CaseIterable, Hashable {
        case timeline = "Timeline"
        case calendar = "Calendar"
    }

    @Published var dayGroups:        [DayGroup]  = []
    @Published var isLoading                     = false
    @Published var errorMessage:     String?     = nil
    @Published var viewMode:         ViewMode    = .timeline
    @Published var calendarMonth:    Date        = Calendar.current.startOfMonth(for: Date())
    @Published var selectedDay:      DayGroup?   = nil
    @Published var daysWithScrobbles: Set<String> = []
    @Published var isLoadingDay                  = false

    private let lastfm = LastFMService()

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    // MARK: Initial load (recent timeline)

    func load() async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else { errorMessage = "No username set"; return }

        isLoading = dayGroups.isEmpty
        defer { isLoading = false }
        do {
            let tracks = try await lastfm.getRecentTracks(user: username, limit: 200)
            let groups = group(tracks.filter { !$0.isNowPlaying })
            dayGroups = groups
            daysWithScrobbles = Set(groups.map { $0.id })
            errorMessage = nil
        } catch {
            if dayGroups.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    // MARK: Calendar month navigation

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
            let groups = group(tracks.filter { !$0.isNowPlaying })
            var byId = Dictionary(uniqueKeysWithValues: dayGroups.map { ($0.id, $0) })
            for g in groups { byId[g.id] = g }
            dayGroups            = byId.values.sorted { $0.date > $1.date }
            daysWithScrobbles    = Set(dayGroups.map { $0.id })
        } catch {}
    }

    // MARK: Day detail load

    func loadDay(_ date: Date) async {
        let key = Self.dayFmt.string(from: date)

        if let existing = dayGroups.first(where: { $0.id == key }) {
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) { selectedDay = existing }
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
            let groups = group(tracks.filter { !$0.isNowPlaying })
            let result = groups.first(where: { $0.id == key })
                ?? DayGroup(id: key, date: date, tracks: [])

            // Cache
            var byId = Dictionary(uniqueKeysWithValues: dayGroups.map { ($0.id, $0) })
            byId[key] = result
            dayGroups         = byId.values.sorted { $0.date > $1.date }
            daysWithScrobbles = Set(dayGroups.map { $0.id })

            withAnimation(.spring(duration: 0.35, bounce: 0.1)) { selectedDay = result }
        } catch {
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                selectedDay = DayGroup(id: key, date: date, tracks: [])
            }
        }
        isLoadingDay = false
    }

    // MARK: Helpers

    private func group(_ tracks: [ScrobbledTrack]) -> [DayGroup] {
        var grouped: [String: [ScrobbledTrack]] = [:]
        for t in tracks {
            let key = Self.dayFmt.string(from: t.timestamp)
            grouped[key, default: []].append(t)
        }
        return grouped.map { key, ts in
            DayGroup(id: key, date: Self.dayFmt.date(from: key) ?? Date(), tracks: ts)
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
