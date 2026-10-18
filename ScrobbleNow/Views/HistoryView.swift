import SwiftUI

private struct AlbumRef: Identifiable {
    let id = UUID()
    let name: String
    let artist: String
}

struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()
    let onAlbumTap: (String, String) -> Void

    @State private var collapsedSessions: Set<String> = []
    @State private var lovedOverrides: [String: Bool] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let loveService = LastFMService()

    #if os(iOS)
    @State private var albumSheet: AlbumRef?
    #endif

    // MARK: Platform sizing
    #if os(iOS)
    private let artSize: CGFloat = 46
    private let artCorner: CGFloat = 8
    private let trackNameFont: Font = .system(size: 14, weight: .medium)
    private let artistFont: Font = .system(size: 12)
    private let timeFont: Font = .system(size: 10, design: .monospaced)
    private let rowVPad: CGFloat = 10
    private let headerFontSz: CGFloat = 15
    #else
    private let artSize: CGFloat = 26
    private let artCorner: CGFloat = 4
    private let trackNameFont: Font = .system(size: 9, weight: .medium)
    private let artistFont: Font = .system(size: 8)
    private let timeFont: Font = .system(size: 7, design: .monospaced)
    private let rowVPad: CGFloat = 3
    private let headerFontSz: CGFloat = 10
    #endif

    private let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        VStack(spacing: 0) {
            modeToggle
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider().opacity(0.15)

            Group {
                if vm.isLoading && vm.dayGroups.isEmpty {
                    loadingView
                } else {
                    switch vm.viewMode {
                    case .timeline: timelineView
                    case .calendar: calendarOrDetail
                    }
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: vm.viewMode)
        }
        .task { await vm.load() }
        #if os(iOS)
        .sheet(item: $albumSheet) { ref in
            NavigationStack {
                AlbumDetailView(albumName: ref.name, artistName: ref.artist)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { albumSheet = nil }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        #endif
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(HistoryViewModel.ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        vm.viewMode = mode
                        vm.selectedDay = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode == .timeline ? "clock" : "calendar")
                            .font(.system(size: 11, weight: .medium))
                        Text(mode.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(vm.viewMode == mode ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(vm.viewMode == mode ? AppAccent.current.opacity(0.85) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06), in: Capsule())
        .sensoryFeedback(.selection, trigger: vm.viewMode)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView().scaleEffect(0.9)
            Text("Loading history…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Timeline Mode

    private var timelineView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Streak banner
                if vm.streak >= 2 {
                    streakBanner
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ForEach(vm.dayGroups) { day in
                    dayTimelineSection(day)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Streak Banner

    private var streakBanner: some View {
        HStack(spacing: 10) {
            Text("🔥")
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(vm.streak)-day streak")
                    .font(.system(size: 13, weight: .bold))
                Text("Keep it going")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(vm.streak)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppAccent.current)
                .contentTransition(.numericText(value: Double(vm.streak)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppAccent.current.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppAccent.current.opacity(0.2), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Day Section (Timeline)

    private func dayTimelineSection(_ day: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.displayDate)
                        .font(.system(size: headerFontSz, weight: .bold))
                    if let span = day.listeningSpan {
                        Text(span)
                            .font(.system(size: headerFontSz - 4, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    statPill("\(day.totalScrobbles)", icon: "music.note")
                    statPill("\(day.uniqueArtists)", icon: "person")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.025))

            // Sessions
            ForEach(day.sessions) { session in
                sessionSection(session, in: day)
            }
        }
    }

    // MARK: - Session Section

    private func sessionSection(_ session: ListeningSession, in day: DayGroup) -> some View {
        let isCollapsed = collapsedSessions.contains(session.id)

        return VStack(spacing: 0) {
            // Session header
            Button {
                withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(duration: 0.3, bounce: 0.1)) {
                    if isCollapsed {
                        collapsedSessions.remove(session.id)
                    } else {
                        collapsedSessions.insert(session.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: session.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(AppAccent.current)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.timeLabel)
                            .font(.system(size: 11, weight: .semibold))
                        Text(session.timeRangeLabel)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }

                    Spacer()

                    if let artist = session.topArtist {
                        Text(artist)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text("\(session.trackCount)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.015))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(session.timeLabel), \(session.trackCount) tracks, \(isCollapsed ? "collapsed" : "expanded")")
            .accessibilityHint("Double-tap to \(isCollapsed ? "expand" : "collapse")")
            .sensoryFeedback(.impact(weight: .light), trigger: isCollapsed)

            // Track list (collapsible)
            if !isCollapsed {
                trackList(session.tracks, onAlbumTap: handleAlbumTap)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Calendar or Detail

    private var calendarOrDetail: some View {
        ZStack(alignment: .top) {
            calendarView
                .opacity(vm.selectedDay != nil ? 0 : 1)

            if let day = vm.selectedDay {
                dayDetailView(day: day)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.12) : .spring(duration: 0.38, bounce: 0.1), value: vm.selectedDay?.id)
        .clipped()
    }

    // MARK: - Calendar Grid

    private var calendarView: some View {
        VStack(spacing: 0) {
            // Month navigation
            HStack {
                Button {
                    let prev = Calendar.current.date(byAdding: .month, value: -1, to: vm.calendarMonth)!
                    vm.goToMonth(prev)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 1) {
                    Text(vm.calendarMonth, format: .dateTime.month(.wide).year())
                        .font(.system(size: 15, weight: .semibold))
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.25), value: vm.calendarMonth)

                    // Month total
                    let monthKey = monthKey(vm.calendarMonth)
                    let monthTotal = vm.dayGroups
                        .filter { $0.id.hasPrefix(monthKey) }
                        .reduce(0) { $0 + $1.totalScrobbles }
                    if monthTotal > 0 {
                        Text("\(monthTotal) scrobbles")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .contentTransition(.numericText(value: Double(monthTotal)))
                    }
                }

                Spacer()

                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: vm.calendarMonth)!
                Button {
                    guard nextMonth <= Date() else { return }
                    vm.goToMonth(nextMonth)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(nextMonth > Date() ? .quaternary : .secondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(nextMonth > Date())
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            // Weekday labels
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 2)

            // Day grid
            let cells = calendarCells(for: vm.calendarMonth)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                spacing: 4
            ) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell.day, let date = cell.date {
                        calendarCell(day: day, date: date)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 8)
            .animation(.smooth(duration: 0.3), value: vm.calendarMonth)

            if vm.isLoading {
                ProgressView().scaleEffect(0.65).padding(.top, 14)
            }

            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private func calendarCell(day: Int, date: Date) -> some View {
        let key          = dayKey(date)
        let group        = vm.dayGroups.first(where: { $0.id == key })
        let count        = group?.totalScrobbles ?? 0
        let hasScrobbles = count > 0
        let isToday      = Calendar.current.isDateInToday(date)
        let isFuture     = date > Date()

        // Log-scale intensity so visual range feels natural
        let intensity: Double = hasScrobbles
            ? min(1.0, log(Double(count) + 1) / log(55))
            : 0

        Button {
            guard !isFuture, hasScrobbles else { return }
            Task { await vm.loadDay(date) }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    // Heatmap fill
                    if intensity > 0 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppAccent.current.opacity(0.1 + 0.75 * intensity))
                    }
                    // Today ring
                    if isToday {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(AppAccent.current, lineWidth: 1.5)
                    }

                    VStack(spacing: 1) {
                        Text("\(day)")
                            .font(.system(size: 12, weight: isToday ? .bold : intensity > 0.4 ? .medium : .regular))
                            .foregroundColor(
                                isFuture ? Color.primary.opacity(0.2)
                                : intensity > 0.55 ? Color.white
                                : hasScrobbles ? Color.primary
                                : Color.primary.opacity(0.3)
                            )
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                                .foregroundStyle(intensity > 0.55 ? .white.opacity(0.85) : AppAccent.current.opacity(0.9))
                        } else {
                            Color.clear.frame(height: 8)
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelForDay(day: day, date: date, count: count, isFuture: isFuture))
        .accessibilityHint(hasScrobbles && !isFuture ? "Double-tap to view" : "")
        .sensoryFeedback(.impact(weight: .light), trigger: vm.selectedDay?.id == key)
    }

    private func accessibilityLabelForDay(day: Int, date: Date, count: Int, isFuture: Bool) -> String {
        let dayStr = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if isFuture { return dayStr }
        if count == 0 { return "\(dayStr), no scrobbles" }
        return "\(dayStr), \(count) scrobble\(count == 1 ? "" : "s")"
    }

    // MARK: - Day Detail View

    private func dayDetailView(day: DayGroup) -> some View {
        VStack(spacing: 0) {
            // Rich header
            dayDetailHeader(day)

            Divider().opacity(0.15)

            if vm.isLoadingDay {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Text("Loading…").font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                }
            } else if day.tracks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 26))
                        .foregroundStyle(.quaternary)
                    Text("No scrobbles on this day")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(day.sessions) { session in
                            sessionSection(session, in: day)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private func dayDetailHeader(_ day: DayGroup) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Blurred artwork background
            if let url = day.topArtworkURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 35)
                            .opacity(0.45)
                            .clipped()
                    }
                }
            }

            // Gradient vignette
            LinearGradient(
                colors: [.black.opacity(0.15), .black.opacity(0.7)],
                startPoint: .top, endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Back button
                Button {
                    withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(duration: 0.38, bounce: 0.1)) {
                        vm.selectedDay = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text(vm.calendarMonth, format: .dateTime.month(.abbreviated).year())
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.3), in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(day.displayDate)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    Label("\(day.totalScrobbles) tracks", systemImage: "music.note")
                    Label("\(day.uniqueArtists) artists", systemImage: "person.2")
                    if let span = day.listeningSpan {
                        Label(span, systemImage: "clock")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.75))
                .labelStyle(.titleAndIcon)

                // Top artists row
                if day.uniqueArtists > 1 {
                    let topArtists = Array(
                        Dictionary(grouping: day.tracks, by: { $0.artistName })
                            .sorted { $0.value.count > $1.value.count }
                            .prefix(3)
                            .map { $0.key }
                    )
                    HStack(spacing: 6) {
                        ForEach(topArtists, id: \.self) { artist in
                            Text(artist)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.15), in: Capsule())
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(14)
        }
        #if os(iOS)
        .frame(height: 180)
        #else
        .frame(height: 120)
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    // MARK: - Track List (shared)

    @ViewBuilder
    private func trackList(_ tracks: [ScrobbledTrack], onAlbumTap: @escaping (String, String) -> Void) -> some View {
        ForEach(tracks) { track in
            let isLoved = lovedOverrides[track.id] ?? track.loved
            trackRow(track, isLoved: isLoved)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !track.albumName.isEmpty else { return }
                    onAlbumTap(track.albumName, track.artistName)
                }
                .contextMenu {
                    Button {
                        toggleLove(track, currentlyLoved: isLoved)
                    } label: {
                        Label(isLoved ? "Unlove" : "Love", systemImage: isLoved ? "heart.slash" : "heart.fill")
                    }
                    if let url = track.lastfmURL {
                        Button { openURL(url) } label: {
                            Label("Open on Last.fm", systemImage: "safari")
                        }
                    }
                    Divider()
                    Button {
                        copyToClipboard("\(track.artistName) - \(track.name)")
                    } label: {
                        Label("Copy Track Info", systemImage: "doc.on.doc")
                    }
                }
                #if os(iOS)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        toggleLove(track, currentlyLoved: isLoved)
                    } label: {
                        Label(isLoved ? "Unlove" : "Love", systemImage: isLoved ? "heart.slash" : "heart.fill")
                    }
                    .tint(isLoved ? .gray : .pink)
                }
                .swipeActions(edge: .trailing) {
                    if let url = track.lastfmURL {
                        Button { openURL(url) } label: { Label("Last.fm", systemImage: "safari") }
                            .tint(Color(red: 0.85, green: 0.1, blue: 0.1))
                    }
                }
                #endif
                .scrollTransition(.interactive) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.45)
                        .offset(x: phase.value * 5)
                }
        }
    }

    // MARK: - Track Row

    private func trackRow(_ track: ScrobbledTrack, isLoved: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(timeString(track.timestamp))
                .font(timeFont)
                .foregroundStyle(.quaternary)
                .frame(width: 36, alignment: .trailing)

            VStack(spacing: 0) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
                Circle()
                    .fill(isLoved ? Color.red : AppAccent.current.opacity(0.45))
                    .frame(width: 5, height: 5)
                Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
            }
            .frame(width: 5)

            AsyncImage(url: track.albumArtworkURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    Color.gray.opacity(0.1)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: artSize * 0.3))
                                .foregroundStyle(.quaternary)
                        }
                }
            }
            .frame(width: artSize, height: artSize)
            .clipShape(RoundedRectangle(cornerRadius: artCorner))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(trackNameFont)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(track.artistName)
                        .font(artistFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if !track.albumName.isEmpty {
                        Text("·")
                            .font(artistFont)
                            .foregroundStyle(.quaternary)
                        Text(track.albumName)
                            .font(artistFont)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            if isLoved {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
                    .accessibilityLabel("Loved")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowVPad)
    }

    // MARK: - Stat Pill

    private func statPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 7))
            Text(text).font(.system(size: 8, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Love / URL / Clipboard

    private func toggleLove(_ track: ScrobbledTrack, currentlyLoved: Bool) {
        let newState = !currentlyLoved
        lovedOverrides[track.id] = newState
        Task {
            do {
                if newState {
                    try await loveService.loveTrack(artist: track.artistName, track: track.name)
                } else {
                    try await loveService.unloveTrack(artist: track.artistName, track: track.name)
                }
            } catch {
                // Revert on failure
                await MainActor.run { lovedOverrides[track.id] = currentlyLoved }
            }
        }
    }

    private func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    // MARK: - Tap Handler

    private func handleAlbumTap(_ album: String, _ artist: String) {
        onAlbumTap(album, artist)
        #if os(iOS)
        albumSheet = AlbumRef(name: album, artist: artist)
        #endif
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String { HistoryGrouping.timeString(date) }

    private func dayKey(_ date: Date) -> String { HistoryGrouping.dayKey(date) }

    private func monthKey(_ date: Date) -> String { String(HistoryGrouping.dayKey(date).prefix(7)) }

    private func calendarCells(for month: Date) -> [(day: Int?, date: Date?)] {
        let cal   = Calendar.current
        let start = cal.startOfMonth(for: month)
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }

        let firstWeekday = cal.component(.weekday, from: start)
        let offset = (firstWeekday - 2 + 7) % 7  // Monday-first

        var cells: [(day: Int?, date: Date?)] = Array(repeating: (nil, nil), count: offset)
        for day in range {
            let date = cal.date(byAdding: .day, value: day - 1, to: start)!
            cells.append((day: day, date: date))
        }
        while cells.count % 7 != 0 { cells.append((nil, nil)) }
        return cells
    }
}
