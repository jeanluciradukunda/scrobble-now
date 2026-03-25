import SwiftUI

struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()
    let onAlbumTap: (String, String) -> Void

    // Platform-adaptive sizing
    #if os(iOS)
    private let artSize:        CGFloat = 44
    private let cornerRadius:   CGFloat = 8
    private let trackNameFont:  Font    = .system(size: 14, weight: .medium)
    private let artistFont:     Font    = .system(size: 12)
    private let timeFont:       Font    = .system(size: 10, design: .monospaced)
    private let dayHeaderFont:  Font    = .system(size: 15, weight: .bold)
    private let rowVPad:        CGFloat = 10
    private let statIconSize:   CGFloat = 9
    private let statTextSize:   CGFloat = 10
    #else
    private let artSize:        CGFloat = 24
    private let cornerRadius:   CGFloat = 4
    private let trackNameFont:  Font    = .system(size: 9, weight: .medium)
    private let artistFont:     Font    = .system(size: 8)
    private let timeFont:       Font    = .system(size: 7, design: .monospaced)
    private let dayHeaderFont:  Font    = .system(size: 10, weight: .bold)
    private let rowVPad:        CGFloat = 3
    private let statIconSize:   CGFloat = 6
    private let statTextSize:   CGFloat = 7
    #endif

    private let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        VStack(spacing: 0) {
            modeToggle
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider().opacity(0.2)

            Group {
                if vm.isLoading && vm.dayGroups.isEmpty {
                    loadingPlaceholder
                } else {
                    switch vm.viewMode {
                    case .timeline:
                        timelineView
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    case .calendar:
                        calendarOrDetail
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .animation(.smooth(duration: 0.25), value: vm.viewMode)
        }
        .task { await vm.load() }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(HistoryViewModel.ViewMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        vm.viewMode = m
                        vm.selectedDay = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m == .timeline ? "clock" : "calendar")
                            .font(.system(size: 11, weight: .medium))
                        Text(m.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(vm.viewMode == m ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(vm.viewMode == m ? AppAccent.current.opacity(0.85) : Color.clear)
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

    private var loadingPlaceholder: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView().scaleEffect(0.9)
            Text("Loading history…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Timeline

    private var timelineView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(vm.dayGroups) { day in
                    daySectionWithHeader(day)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Calendar or Day Detail

    @ViewBuilder
    private var calendarOrDetail: some View {
        if let day = vm.selectedDay {
            dayDetailView(day: day)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            calendarView
                .transition(.move(edge: .leading).combined(with: .opacity))
        }
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
                        .frame(width: 40, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(vm.calendarMonth, format: .dateTime.month(.wide).year())
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: vm.calendarMonth)

                Spacer()

                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: vm.calendarMonth)!
                Button {
                    guard nextMonth <= Date() else { return }
                    vm.goToMonth(nextMonth)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(nextMonth > Date() ? .quaternary : .secondary)
                        .frame(width: 40, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(nextMonth > Date())
            }
            .padding(.horizontal, 12)

            // Weekday labels
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Day grid
            let cells = calendarCells(for: vm.calendarMonth)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 6
            ) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if let day = cell.day, let date = cell.date {
                        calendarDayCell(day: day, date: date)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, 8)
            .animation(.smooth(duration: 0.3), value: vm.calendarMonth)

            if vm.isLoading {
                ProgressView()
                    .scaleEffect(0.65)
                    .padding(.top, 16)
            }

            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private func calendarDayCell(day: Int, date: Date) -> some View {
        let key           = dayKey(date)
        let hasScrobbles  = vm.daysWithScrobbles.contains(key)
        let isToday       = Calendar.current.isDateInToday(date)
        let isFuture      = date > Date()
        let count         = vm.dayGroups.first(where: { $0.id == key })?.totalScrobbles

        Button {
            guard !isFuture, hasScrobbles else { return }
            Task { await vm.loadDay(date) }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isToday {
                        Circle()
                            .stroke(AppAccent.current, lineWidth: 1.5)
                            .padding(1)
                    }
                    if hasScrobbles && !isFuture {
                        Circle()
                            .fill(AppAccent.current.opacity(0.15))
                    }
                    Text("\(day)")
                        .font(.system(size: 13, weight: isToday ? .bold : .regular))
                        .foregroundStyle(
                            isFuture ? .quaternary
                            : hasScrobbles ? .primary
                            : .tertiary
                        )
                }
                .frame(width: 32, height: 32)

                // Scrobble count dot
                if hasScrobbles, let count {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppAccent.current.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Color.clear.frame(height: 10)
                }
            }
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Day Detail (calendar → day drill-down)

    private func dayDetailView(day: DayGroup) -> some View {
        VStack(spacing: 0) {
            // Header: back + day title + stats
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                        vm.selectedDay = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text(vm.calendarMonth, format: .dateTime.month(.abbreviated).year())
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AppAccent.current)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(day.displayDate)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 8) {
                    statPill("\(day.totalScrobbles)", icon: "music.note")
                    statPill("\(day.uniqueArtists)", icon: "person")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.2)

            if vm.isLoadingDay {
                Spacer()
                ProgressView().scaleEffect(0.8)
                Text("Loading…")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                Spacer()
            } else if day.tracks.isEmpty {
                Spacer()
                Image(systemName: "music.note.list")
                    .font(.system(size: 24))
                    .foregroundStyle(.quaternary)
                    .padding(.bottom, 6)
                Text("No scrobbles on this day")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        trackList(day.tracks)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    // MARK: - Day Section with Header (timeline mode)

    private func daySectionWithHeader(_ day: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(day.displayDate)
                    .font(dayHeaderFont)
                Spacer()
                HStack(spacing: 8) {
                    statPill("\(day.totalScrobbles)", icon: "music.note")
                    statPill("\(day.uniqueArtists)", icon: "person")
                    statPill("\(day.uniqueAlbums)", icon: "square.stack")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.025))

            trackList(day.tracks)
        }
    }

    // MARK: - Track List

    @ViewBuilder
    private func trackList(_ tracks: [ScrobbledTrack]) -> some View {
        ForEach(tracks) { track in
            trackRow(track)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !track.albumName.isEmpty else { return }
                    onAlbumTap(track.albumName, track.artistName)
                }
                .scrollTransition(.interactive) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.45)
                        .offset(x: phase.value * 6)
                }
        }
    }

    // MARK: - Track Row

    private func trackRow(_ track: ScrobbledTrack) -> some View {
        HStack(spacing: 10) {
            // Time
            Text(timeString(track.timestamp))
                .font(timeFont)
                .foregroundStyle(.quaternary)
                .frame(width: 36, alignment: .trailing)

            // Timeline connector
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                Circle()
                    .fill(track.loved ? Color.red : AppAccent.current.opacity(0.5))
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
            }
            .frame(width: 6)

            // Artwork
            AsyncImage(url: track.albumArtworkURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    Color.gray.opacity(0.1)
                }
            }
            .frame(width: artSize, height: artSize)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(trackNameFont)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(artistFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if track.loved {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowVPad)
    }

    // MARK: - Stat Pill

    private func statPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: statIconSize))
            Text(text)
                .font(.system(size: statTextSize, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }

    private func dayKey(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    private func calendarCells(for month: Date) -> [(day: Int?, date: Date?)] {
        let cal   = Calendar.current
        let start = cal.startOfMonth(for: month)
        guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }

        // Monday-first offset: Mon=0, Tue=1, … Sun=6
        let firstWeekday = cal.component(.weekday, from: start)
        let offset       = (firstWeekday - 2 + 7) % 7

        var cells: [(day: Int?, date: Date?)] = Array(repeating: (nil, nil), count: offset)
        for day in range {
            let date = cal.date(byAdding: .day, value: day - 1, to: start)!
            cells.append((day: day, date: date))
        }
        while cells.count % 7 != 0 { cells.append((nil, nil)) }
        return cells
    }
}
