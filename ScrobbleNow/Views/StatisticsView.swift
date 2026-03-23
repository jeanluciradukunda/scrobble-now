import SwiftUI

struct StatisticsView: View {
    @StateObject private var vm = StatisticsViewModel()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                if vm.isLoading {
                    Spacer().frame(height: 40)
                    ProgressView().scaleEffect(0.8)
                    Text("Loading stats...")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                } else {
                    // Big number cards
                    statsCards

                    // Top artists bar chart
                    if !vm.topArtistBars.isEmpty {
                        barChart
                    }

                    // Genre breakdown
                    if !vm.genreSlices.isEmpty {
                        genreChart
                    }
                }
            }
            .padding(16)
        }
        .task { await vm.load() }
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
        ], spacing: 6) {
            statCard(value: formatNumber(vm.totalScrobbles), label: "Total Scrobbles", icon: "music.note.list")
            statCard(value: "\(vm.scrobblesToday)", label: "Today", icon: "calendar")
            statCard(value: "\(vm.scrobblesThisWeek)", label: "This Week", icon: "chart.bar")
            statCard(value: vm.registeredDate, label: "Since", icon: "clock")
        }
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(AppAccent.current)
                Text(label.uppercased())
                    .font(.system(size: 6, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                }
        }
    }

    // MARK: - Bar Chart (FlowingData-inspired horizontal bars)

    private var barChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOP ARTISTS · 7 DAYS")
                .font(.system(size: 7, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.tertiary)

            ForEach(Array(vm.topArtistBars.enumerated()), id: \.element.id) { i, bar in
                HStack(spacing: 6) {
                    Text("\(i + 1)")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .frame(width: 12, alignment: .trailing)

                    // Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.03))

                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [AppAccent.current.opacity(0.6), AppAccent.current.opacity(0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * bar.fraction)

                            HStack(spacing: 0) {
                                Text(bar.name)
                                    .font(.system(size: 8, weight: .medium))
                                    .lineLimit(1)
                                    .padding(.leading, 6)
                                Spacer(minLength: 4)
                                Text("\(bar.playcount)")
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 6)
                            }
                        }
                    }
                    .frame(height: 20)
                }
            }
        }
    }

    // MARK: - Genre Breakdown (FlowingData-inspired)

    private var genreChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GENRES · 7 DAYS")
                .font(.system(size: 7, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.tertiary)

            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(vm.genreSlices) { slice in
                        let width = max(8, geo.size.width * slice.fraction / totalGenreFraction)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(genreColor(for: slice.name))
                            .frame(width: width, height: 16)
                    }
                }
            }
            .frame(height: 16)

            // Legend
            FlowLayout(spacing: 4) {
                ForEach(vm.genreSlices) { slice in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(genreColor(for: slice.name))
                            .frame(width: 5, height: 5)
                        Text(slice.name)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var totalGenreFraction: Double {
        vm.genreSlices.reduce(0) { $0 + $1.fraction }
    }

    private func genreColor(for name: String) -> Color {
        let colors: [Color] = [
            AppAccent.current, .orange, .teal, .purple, .pink, .green, .indigo, .yellow
        ]
        let hash = abs(name.hashValue) % colors.count
        return colors[hash]
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - FlowLayout for wrapping genre tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowLayout(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func flowLayout(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (offsets, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
