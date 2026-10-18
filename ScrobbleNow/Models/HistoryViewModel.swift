import SwiftUI

// MARK: - Listening Session

struct ListeningSession: Identifiable {
    /// Newest first.
    let tracks: [ScrobbledTrack]

    var id: String {
        "\(Int(startTime.timeIntervalSince1970))-\(Int(endTime.timeIntervalSince1970))"
    }

    var startTime: Date { tracks.last?.timestamp ?? Date() }
    var endTime: Date { tracks.first?.timestamp ?? Date() }
    var trackCount: Int { tracks.count }

    var timeLabel: String {
        switch Calendar.current.component(.hour, from: startTime) {
        case 5..<9: return "Early Morning"
        case 9..<12: return "Morning"
        case 12..<14: return "Lunchtime"
        case 14..<17: return "Afternoon"
        case 17..<20: return "Evening"
        case 20..<23: return "Night"
        default: return "Late Night"
        }
    }

    var icon: String {
        switch Calendar.current.component(.hour, from: startTime) {
        case 5..<8: return "sunrise.fill"
        case 8..<12: return "sun.max.fill"
        case 12..<14: return "fork.knife"
        case 14..<17: return "sun.haze.fill"
        case 17..<20: return "sunset.fill"
        case 20..<23: return "moon.stars.fill"
        default: return "moon.fill"
        }
    }

    var timeRangeLabel: String {
        let start = HistoryGrouping.timeString(startTime)
        guard Calendar.current.isDate(startTime, inSameDayAs: endTime) else { return start }
        return "\(start) to \(HistoryGrouping.timeString(endTime))"
    }

    var topArtist: String? { HistoryGrouping.mostCommon(tracks.map(\.artistName)) }

    var topArtworkURL: URL? {
        Dictionary(grouping: tracks, by: \.albumName)
            .max { $0.value.count < $1.value.count }?
            .value.first?.albumArtworkURL
    }
}

// MARK: - DayGroup

struct DayGroup: Identifiable {
    let id: String
    let date: Date
    let tracks: [ScrobbledTrack]

    var displayDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var totalScrobbles: Int { tracks.count }
    var uniqueArtists: Int { Set(tracks.map { $0.artistName.lowercased() }).count }
    var uniqueAlbums: Int { Set(tracks.map { $0.albumName.lowercased() }).count }
    var topArtist: String? { HistoryGrouping.mostCommon(tracks.map(\.artistName)) }

    var topArtworkURL: URL? {
        Dictionary(grouping: tracks, by: \.albumName)
            .max { $0.value.count < $1.value.count }?
            .value.first?.albumArtworkURL
    }

    var listeningSpan: String? {
        guard let first = tracks.last?.timestamp, let last = tracks.first?.timestamp else { return nil }
        return "\(HistoryGrouping.timeString(first)) to \(HistoryGrouping.timeString(last))"
    }

    var sessions: [ListeningSession] { HistoryGrouping.sessions(tracks) }
}

// MARK: - Pure grouping logic

enum HistoryGrouping {
    /// Built from date components, so keys stay "yyyy-MM-dd" whatever calendar or locale the user has chosen.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func timeString(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func mostCommon(_ values: [String]) -> String? {
        Dictionary(grouping: values, by: { $0 }).max { $0.value.count < $1.value.count }?.key
    }

    /// Groups tracks into local calendar days, newest day first, tracks newest first.
    static func days(_ tracks: [ScrobbledTrack], calendar: Calendar = .current) -> [DayGroup] {
        Dictionary(grouping: tracks) { dayKey($0.timestamp, calendar: calendar) }
            .compactMap { key, dayTracks -> DayGroup? in
                guard let first = dayTracks.first else { return nil }
                return DayGroup(id: key, date: calendar.startOfDay(for: first.timestamp),
                                tracks: dayTracks.sorted { $0.timestamp > $1.timestamp })
            }
            .sorted { $0.date > $1.date }
    }

    /// Splits newest-first tracks into sessions wherever the gap between scrobbles exceeds `gap`.
    static func sessions(_ tracks: [ScrobbledTrack], gap: TimeInterval = 30 * 60) -> [ListeningSession] {
        guard let first = tracks.first else { return [] }
        var groups: [[ScrobbledTrack]] = []
        var current = [first]
        for (newer, older) in zip(tracks, tracks.dropFirst()) {
            if newer.timestamp.timeIntervalSince(older.timestamp) > gap {
                groups.append(current)
                current = [older]
            } else {
                current.append(older)
            }
        }
        groups.append(current)
        return groups.map { ListeningSession(tracks: $0) }
    }

    /// Consecutive days with scrobbles, ending today, or yesterday if nothing has been played yet today.
    static func streak(days: Set<String>, today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !days.contains(dayKey(day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(dayKey(day, calendar: calendar)), count < 3650 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// A full page of the latest scrobbles usually starts part-way through its oldest day; merging that partial
    /// day would replace a complete one loaded by month, so it is dropped.
    static func completeDays(from tracks: [ScrobbledTrack], pageWasFull: Bool, calendar: Calendar = .current) -> [DayGroup] {
        let groups = days(tracks, calendar: calendar)
        return pageWasFull && groups.count > 1 ? Array(groups.dropLast()) : groups
    }

    static func merging(_ existing: [DayGroup], with fresh: [DayGroup]) -> [DayGroup] {
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for group in fresh { byID[group.id] = group }
        return byID.values.sorted { $0.date > $1.date }
    }
}

// MARK: - HistoryViewModel

@MainActor
class HistoryViewModel: ObservableObject {
    enum ViewMode: String, CaseIterable, Hashable {
        case timeline = "Timeline"
        case calendar = "Calendar"
    }

    @Published var dayGroups: [DayGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var viewMode: ViewMode = .timeline
    @Published var calendarMonth: Date = Calendar.current.startOfMonth(for: Date())
    @Published var selectedDay: DayGroup?
    @Published var daysWithScrobbles: Set<String> = []
    @Published var isLoadingDay = false

    private let lastfm = LastFMService()

    var streak: Int { HistoryGrouping.streak(days: daysWithScrobbles, today: Date()) }

    func load() async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else {
            errorMessage = "No username set"
            return
        }
        isLoading = dayGroups.isEmpty
        defer { isLoading = false }
        do {
            let tracks = try await lastfm.getRecentTracks(user: username, limit: 200)
            let pageWasFull = tracks.filter { !$0.isNowPlaying }.count >= 200
            apply(HistoryGrouping.completeDays(from: tracks.filter { !$0.isNowPlaying }, pageWasFull: pageWasFull),
                  replacing: false)
            errorMessage = nil
            await loadStreakWindow(latestPageWasFull: pageWasFull)
        } catch {
            if dayGroups.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    /// The streak and the calendar need whole months, not just the latest 200 scrobbles.
    private func loadStreakWindow(latestPageWasFull: Bool) async {
        let cal = Calendar.current
        let thisMonth = cal.startOfMonth(for: Date())
        if latestPageWasFull { await loadMonth(thisMonth) }
        let daysIntoMonth = (cal.dateComponents([.day], from: thisMonth, to: cal.startOfDay(for: Date())).day ?? 0) + 1
        if streak >= daysIntoMonth, let previous = cal.date(byAdding: .month, value: -1, to: thisMonth) {
            await loadMonth(previous)
        }
    }

    func goToMonth(_ month: Date) {
        calendarMonth = month
        Task { await loadMonth(month) }
    }

    func loadMonth(_ month: Date) async {
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else { return }
        let cal = Calendar.current
        let start = cal.startOfMonth(for: month)
        guard let end = cal.date(byAdding: .month, value: 1, to: start) else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            let tracks = try await lastfm.getAllRecentTracks(user: username, from: start, to: end)
            apply(HistoryGrouping.days(tracks), replacing: false)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDay(_ date: Date) async {
        let key = HistoryGrouping.dayKey(date)
        if let existing = dayGroups.first(where: { $0.id == key }) {
            withAnimation(.spring(duration: 0.38, bounce: 0.1)) { selectedDay = existing }
            return
        }
        let username = SettingsManager.shared.lastfmUsername
        guard !username.isEmpty else { return }

        isLoadingDay = true
        defer { isLoadingDay = false }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        var result = DayGroup(id: key, date: start, tracks: [])
        if let end = cal.date(byAdding: .day, value: 1, to: start),
           let tracks = try? await lastfm.getAllRecentTracks(user: username, from: start, to: end) {
            result = HistoryGrouping.days(tracks).first { $0.id == key } ?? result
            apply([result], replacing: false)
        }
        withAnimation(.spring(duration: 0.38, bounce: 0.1)) { selectedDay = result }
    }

    private func apply(_ groups: [DayGroup], replacing: Bool) {
        dayGroups = replacing ? groups : HistoryGrouping.merging(dayGroups, with: groups)
        daysWithScrobbles = Set(dayGroups.filter { !$0.tracks.isEmpty }.map(\.id))
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
