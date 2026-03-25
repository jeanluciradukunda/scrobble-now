import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case integrations = "Integrations"
    case developer = "Developer"
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var viewModel: NowPlayingViewModel
    @State private var selectedTab: SettingsTab = .general
    @State private var usernameInput: String = ""
    @State private var isAuthenticating = false
    @State private var authError: String?

    private let lastfmService = LastFMService()

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? AppAccent.current : .secondary)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(selectedTab == tab ? AppAccent.current.opacity(0.08) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    switch selectedTab {
                    case .general: generalTab
                    case .integrations: integrationsTab
                    case .developer: developerTab
                    }
                }
                .padding(16)
            }
        }
    }

    // ═══════════════════════════════════════════
    // MARK: - General Tab
    // ═══════════════════════════════════════════

    private var generalTab: some View {
        Group {
            // Account
            sectionHeader("Account")
            accountSection

            Divider().opacity(0.2)

            // Scrobble Behavior
            sectionHeader("Scrobble Behavior")

            settingsToggle("Enable scrobbling", isOn: $settings.scrobbleEnabled)
            settingsSlider("Scrobble at", value: $settings.scrobbleThresholdPercent, range: 25...90, step: 5, unit: "%")
            settingsSlider("Min track duration", value: Binding(
                get: { Double(settings.minTrackDuration) },
                set: { settings.minTrackDuration = Int($0) }
            ), range: 10...120, step: 10, unit: "s")
            settingsToggle("Filter podcasts", isOn: $settings.filterPodcasts)
            settingsToggle("Album guessing", isOn: $settings.albumGuessing)
            settingsToggle("Scrobble notifications", isOn: $settings.scrobbleNotifications)

            Divider().opacity(0.2)

            // Downloads
            sectionHeader("Downloads")

            #if os(macOS)
            HStack {
                Text("Save artwork to")
                    .font(.system(size: 10))
                Spacer()
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.canCreateDirectories = true
                    panel.prompt = "Choose Folder"
                    if panel.runModal() == .OK, let url = panel.url {
                        settings.artworkDownloadPath = url.path
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                            .font(.system(size: 8))
                        Text(settings.artworkDownloadURL.lastPathComponent)
                            .font(.system(size: 8, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            #endif

            Divider().opacity(0.2)

            // Appearance
            sectionHeader("Appearance")
            #if os(macOS)
            settingsToggle("Show track in menu bar", isOn: $settings.showTitleInMenuBar)
            #endif

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
                ForEach(AppAccent.options) { option in
                    Button {
                        settings.accentColorName = option.id
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 20, height: 20)
                            .overlay {
                                if settings.accentColorName == option.id {
                                    Circle().strokeBorder(.white, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(option.name)
                }
            }

            Spacer(minLength: 8)

            #if os(macOS)
            // Quit
            HStack {
                Spacer()
                Button("Quit Scrobble Now") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.red)
                Spacer()
            }
            #endif
        }
    }

    // ═══════════════════════════════════════════
    // MARK: - Integrations Tab
    // ═══════════════════════════════════════════

    private var integrationsTab: some View {
        Group {
            // App Sources
            sectionHeader("Sources")

            if SystemScrobbleService.shared.connectors.isEmpty {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No sources detected yet")
                            .font(.system(size: 10, weight: .medium))
                        Text("Play music from any app to discover sources")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 8)
            } else {
                ForEach(SystemScrobbleService.shared.connectors) { connector in
                    HStack(spacing: 8) {
                        #if os(macOS)
                        if let icon = MediaRemoteBridge.shared.appIcon(for: connector.bundleId) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)
                                .frame(width: 20, height: 20)
                        }
                        #else
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(width: 20, height: 20)
                        #endif
                        VStack(alignment: .leading, spacing: 1) {
                            Text(connector.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                            Text(connector.bundleId)
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(.quaternary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { connector.enabled },
                            set: { _ in SystemScrobbleService.shared.toggleConnector(bundleId: connector.bundleId) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider().opacity(0.2)

            // API Keys
            sectionHeader("API Keys")

            ForEach(KeychainService.Key.allCases.filter(\.isUserEditable), id: \.rawValue) { key in
                HStack {
                    Text(key.displayName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Spacer()
                    let val = KeychainService.get(key) ?? ""
                    if val.isEmpty {
                        Text("Missing")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.red)
                    } else {
                        HStack(spacing: 4) {
                            Text("•••••••")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Circle()
                                .fill(.green)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }

            Divider().opacity(0.2)

            // Supported Services
            sectionHeader("Supported Services")

            VStack(alignment: .leading, spacing: 4) {
                serviceRow(name: "Spotify", icon: "🟢", detail: "DistributedNotification — instant")
                serviceRow(name: "Apple Music", icon: "🔴", detail: "DistributedNotification — instant")
                serviceRow(name: "YouTube / YouTube Music", icon: "🔴", detail: "Tab scanning — 3s poll")
                serviceRow(name: "SoundCloud", icon: "🟠", detail: "Tab scanning — 3s poll")
                serviceRow(name: "Bandcamp", icon: "🔵", detail: "Tab scanning — 3s poll")
                serviceRow(name: "Tidal / Deezer", icon: "⚫", detail: "Tab scanning — 3s poll")
                serviceRow(name: "Other native apps", icon: "🟣", detail: "MediaRemote — 1s poll")
            }
        }
    }

    private func serviceRow(name: String, icon: String, detail: String) -> some View {
        HStack(spacing: 6) {
            Text(icon).font(.system(size: 8))
            Text(name).font(.system(size: 9, weight: .medium))
            Spacer()
            Text(detail).font(.system(size: 7)).foregroundStyle(.quaternary)
        }
    }

    // ═══════════════════════════════════════════
    // MARK: - Developer Tab
    // ═══════════════════════════════════════════

    #if os(macOS)
    @StateObject private var metrics = MetricsService.shared
    #endif

    private var developerTab: some View {
        Group {
            // ═══════ Stats Cards ═══════
            sectionHeader("Scrobble Statistics")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statCard(value: "\(SystemScrobbleService.shared.totalScrobbled)", label: "Scrobbled", color: AppAccent.current)
                statCard(value: "\(SystemScrobbleService.shared.connectors.filter(\.enabled).count)", label: "Active Sources", color: .green)
                statCard(value: "\(SystemScrobbleService.shared.connectors.count)", label: "Discovered", color: .blue)
                statCard(value: settings.lastfmUsername.isEmpty ? "—" : settings.lastfmUsername, label: "Last.fm User", color: .orange)
            }

            Divider().opacity(0.2)

            // ═══════ Radar Chart ═══════
            sectionHeader("Scoring Radar")

            RadarChartView(
                axes: [
                    ("Title", settings.scoreWeightTitle, 50),
                    ("Artist", settings.scoreWeightArtist, 50),
                    ("Tracks", settings.scoreWeightTracks, 30),
                    ("Source", settings.scoreWeightSource, 30),
                    ("Content", settings.scoreWeightContent, 20),
                ],
                threshold: settings.scoreMinThreshold,
                maxTotal: 180
            )
            .frame(height: 170)
            .padding(.bottom, 4)

            settingsSlider("Title match", value: $settings.scoreWeightTitle, range: 0...50, step: 5, unit: "")
            settingsSlider("Artist match", value: $settings.scoreWeightArtist, range: 0...50, step: 5, unit: "")
            settingsSlider("Track count", value: $settings.scoreWeightTracks, range: 0...30, step: 5, unit: "")
            settingsSlider("Source trust", value: $settings.scoreWeightSource, range: 0...30, step: 5, unit: "")
            settingsSlider("Content", value: $settings.scoreWeightContent, range: 0...20, step: 5, unit: "")
            settingsSlider("Min threshold", value: $settings.scoreMinThreshold, range: 10...80, step: 5, unit: "")

            Button("Reset to Defaults") {
                settings.scoreWeightTitle = 35
                settings.scoreWeightArtist = 30
                settings.scoreWeightTracks = 10
                settings.scoreWeightSource = 15
                settings.scoreWeightContent = 5
                settings.scoreMinThreshold = 40
            }
            .buttonStyle(.plain)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(AppAccent.current)

            Divider().opacity(0.2)

            // ═══════ API Call Stats ═══════
            sectionHeader("API Calls")

            // Summary row
            HStack(spacing: 12) {
                statCard(value: "\(APITracker.shared.totalCalls)", label: "Total Calls", color: .blue)
                statCard(value: "\(APITracker.shared.totalErrors)", label: "Errors", color: .red)
                statCard(value: String(format: "%.0f%%", 100 - APITracker.shared.errorRate), label: "Success", color: .green)
            }

            // Per-service breakdown — bar chart sorted by call count
            if !APITracker.shared.rankedServices.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(APITracker.shared.rankedServices, id: \.service) { stats in
                        HStack(spacing: 6) {
                            Circle().fill(stats.color).frame(width: 6, height: 6)
                            Text(stats.service)
                                .font(.system(size: 8, weight: .medium))
                                .frame(width: 72, alignment: .leading)

                            // Call count bar
                            GeometryReader { geo in
                                let maxCalls = APITracker.shared.rankedServices.first?.totalCalls ?? 1
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.04))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(stats.color.opacity(0.5))
                                        .frame(width: geo.size.width * Double(stats.totalCalls) / Double(max(1, maxCalls)))
                                }
                            }
                            .frame(height: 8)

                            Text("\(stats.totalCalls)")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(stats.color)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Timing table
                VStack(spacing: 0) {
                    // Header
                    HStack(spacing: 0) {
                        Text("Service").frame(width: 72, alignment: .leading)
                        Text("Avg").frame(width: 40, alignment: .trailing)
                        Text("Min").frame(width: 40, alignment: .trailing)
                        Text("Max").frame(width: 40, alignment: .trailing)
                        Text("Err").frame(width: 24, alignment: .trailing)
                    }
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.quaternary)
                    .padding(.vertical, 3)

                    ForEach(APITracker.shared.rankedServices, id: \.service) { stats in
                        HStack(spacing: 0) {
                            HStack(spacing: 3) {
                                Circle().fill(stats.color).frame(width: 4, height: 4)
                                Text(stats.service)
                            }
                            .frame(width: 72, alignment: .leading)
                            Text("\(stats.avgMs)ms").frame(width: 40, alignment: .trailing)
                            Text("\(stats.minMs)ms").frame(width: 40, alignment: .trailing)
                            Text("\(stats.maxMs)ms").frame(width: 40, alignment: .trailing).foregroundStyle(stats.maxMs > 2000 ? .red : .secondary)
                            Text("\(stats.errorCount)").frame(width: 24, alignment: .trailing).foregroundColor(stats.errorCount > 0 ? .red : .gray)
                        }
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6))

                // Response time sparklines per service
                ForEach(APITracker.shared.rankedServices.prefix(3), id: \.service) { stats in
                    if stats.recentDurations.count >= 2 {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(stats.service).font(.system(size: 7, weight: .medium)).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(stats.avgMs)ms avg").font(.system(size: 6, design: .monospaced)).foregroundStyle(stats.color)
                            }
                            SparklineView(data: stats.recentDurations.map { $0 * 1000 }, color: stats.color, height: 18)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Reset Stats") { APITracker.shared.clear() }
                        .buttonStyle(.plain).font(.system(size: 8, weight: .medium)).foregroundStyle(.red)
                }
            }

            Divider().opacity(0.2)

            // ═══════ Source Trust ═══════
            sectionHeader("Source Trust Scores")

            VStack(alignment: .leading, spacing: 4) {
                trustBar(name: "MusicBrainz", score: 12, maxScore: 15, color: .purple)
                trustBar(name: "Discogs", score: 11, maxScore: 15, color: .teal)
                trustBar(name: "Last.fm", score: 10, maxScore: 15, color: .red)
                trustBar(name: "iTunes", score: 8, maxScore: 15, color: .pink)
                trustBar(name: "Wikidata", score: 7, maxScore: 15, color: .blue)
            }

            Divider().opacity(0.2)

            #if os(macOS)
            // ═══════ App Metrics ═══════
            sectionHeader("App Metrics")

            // Gauges
            HStack(spacing: 8) {
                metricGauge(label: "Memory", value: metrics.realMemoryMB, unit: "MB", max: 200, color: .blue)
                metricGauge(label: "CPU", value: metrics.cpuUsagePercent, unit: "%", max: 100, color: .orange)
                metricGauge(label: "Threads", value: Double(metrics.threadCount), unit: "", max: 40, color: .green)
            }

            // Memory sparkline
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Memory").font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f MB", metrics.realMemoryMB))
                        .font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.blue)
                }
                SparklineView(data: metrics.memoryHistory, color: .blue, height: 24)
            }

            // CPU sparkline
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("CPU").font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", metrics.cpuUsagePercent))
                        .font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.orange)
                }
                SparklineView(data: metrics.cpuHistory, color: .orange, height: 24)
            }

            Divider().opacity(0.2)

            // ═══════ Diagnostics ═══════
            sectionHeader("Diagnostics")

            VStack(alignment: .leading, spacing: 3) {
                diagRow("MediaRemote", value: MediaRemoteBridge.shared.currentTrack != nil ? "● Connected" : "○ No data")
                diagRow("Active sources", value: "\(MediaRemoteBridge.shared.activeSources.count)")
                diagRow("Playing", value: MediaRemoteBridge.shared.isPlaying ? "● Yes" : "○ No")
                diagRow("Connectors", value: "\(SystemScrobbleService.shared.connectors.count)")
                diagRow("Last.fm session", value: KeychainService.lastfmSessionKey != nil ? "● Active" : "○ None")
                diagRow("Virtual Memory", value: String(format: "%.2f GB", metrics.virtualMemoryGB))
                diagRow("CPU Time", value: metrics.cpuTimeFormatted)
                diagRow("Threads", value: "\(metrics.threadCount)")
            }
            #else
            // ═══════ Diagnostics (iOS) ═══════
            sectionHeader("Diagnostics")

            VStack(alignment: .leading, spacing: 3) {
                diagRow("Connectors", value: "\(SystemScrobbleService.shared.connectors.count)")
                diagRow("Last.fm session", value: KeychainService.lastfmSessionKey != nil ? "● Active" : "○ None")
            }
            #endif

            Divider().opacity(0.2)

            // ═══════ Cache ═══════
            sectionHeader("Cache & Data")

            HStack {
                Text("Scrobble history").font(.system(size: 10))
                Spacer()
                Button("Clear") { Task { await ScrobbleCache.shared.clearHistory() } }
                    .buttonStyle(.plain).font(.system(size: 8, weight: .medium)).foregroundStyle(.red)
            }
            HStack {
                Text("Discovery cache").font(.system(size: 10))
                Spacer()
                Button("Clear") { }
                    .buttonStyle(.plain).font(.system(size: 8, weight: .medium)).foregroundStyle(.red)
            }
        }
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func weightBar(value: Double, color: Color, label: String) -> some View {
        GeometryReader { geo in
            let total = settings.scoreWeightTitle + settings.scoreWeightArtist + settings.scoreWeightTracks + settings.scoreWeightSource + settings.scoreWeightContent
            let fraction = total > 0 ? value / total : 0

            Rectangle()
                .fill(color.opacity(0.7))
                .frame(width: geo.size.width * fraction)
                .overlay {
                    if fraction > 0.08 {
                        Text(label)
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
    }

    private func trustBar(name: String, score: Int, maxScore: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 9, weight: .medium))
                .frame(width: 75, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.6))
                        .frame(width: geo.size.width * Double(score) / Double(maxScore))
                }
            }
            .frame(height: 10)
            Text("\(score)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 18, alignment: .trailing)
        }
    }

    #if os(macOS)
    private func metricGauge(label: String, value: Double, unit: String, max: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(1, value / max))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(String(format: value >= 10 ? "%.0f" : "%.1f", value))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 5))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .frame(width: 38, height: 38)
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
    #endif

    private func diagRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // ═══════════════════════════════════════════
    // MARK: - Shared Components
    // ═══════════════════════════════════════════

    @ViewBuilder
    private var accountSection: some View {
        if settings.lastfmUsername.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your Last.fm username to start.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    TextField("Username", text: $usernameInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.ultraThinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                                }
                        }

                    Button("Connect") {
                        let trimmed = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        settings.lastfmUsername = trimmed
                        viewModel.startPolling()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppAccent.current, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppAccent.current)
                VStack(alignment: .leading, spacing: 1) {
                    Text(settings.lastfmUsername)
                        .font(.system(size: 11, weight: .bold))
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 5, height: 5)
                        Text("Connected")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Disconnect") {
                    settings.lastfmUsername = ""
                    KeychainService.delete(.lastfmSessionKey)
                }
                .buttonStyle(.plain)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.red)
            }
            .padding(8)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))

            if KeychainService.lastfmSessionKey == nil {
                Button {
                    Task { await authenticate() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill").font(.system(size: 8))
                        Text(isAuthenticating ? "Waiting..." : "Authorize Scrobbling")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(AppAccent.current)
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
            }
        }
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(.system(size: 10))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

    private func settingsSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        HStack {
            Text(label).font(.system(size: 10))
            Spacer()
            Text("\(Int(value.wrappedValue))\(unit)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
            Slider(value: value, in: range, step: step)
                .frame(maxWidth: 100)
                .controlSize(.mini)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(.tertiary)
    }

    private func authenticate() async {
        isAuthenticating = true
        authError = nil
        do {
            let token = try await lastfmService.getAuthToken()
            let authURL = await lastfmService.authURL + "&token=\(token)"
            if let url = URL(string: authURL) {
                #if os(macOS)
                NSWorkspace.shared.open(url)
                #else
                await UIApplication.shared.open(url)
                #endif
            }
            try await Task.sleep(for: .seconds(15))
            let (sessionKey, username) = try await lastfmService.getSession(token: token)
            KeychainService.set(.lastfmSessionKey, value: sessionKey)
            settings.lastfmUsername = username
            viewModel.startPolling()
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }
}
