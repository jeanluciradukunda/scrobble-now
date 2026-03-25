import SwiftUI

// MARK: - Mini EQ Indicator (3-bar animated equalizer for compact cards)

struct MiniEQView: View {
    var color: Color = .accentColor
    var isPlaying: Bool = true

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let barW = (size.width - 3.0) / 3.0
                let phases = [0.0, 0.55, 1.1]
                for (i, phase) in phases.enumerated() {
                    let h = 0.2 + 0.8 * max(0, sin(t * 4.8 + phase * .pi))
                    let barH = max(2, size.height * CGFloat(h))
                    let x = CGFloat(i) * (barW + 1.5)
                    let rect = CGRect(x: x, y: size.height - barH, width: barW, height: barH)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.0),
                             with: .color(color.opacity(0.65 + 0.35 * h)))
                }
            }
        }
    }
}

// MARK: - Theme

enum VisualizerTheme: String, CaseIterable {
    case bars = "Bars & Waves"
    case alchemy = "Alchemy"
    case battery = "Battery"
    case spikes = "Spikes"
    case ambience = "Ambience"

    var next: VisualizerTheme {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var icon: String {
        switch self {
        case .bars:     return "waveform"
        case .alchemy:  return "aqi.medium"
        case .battery:  return "circle.grid.3x3.fill"
        case .spikes:   return "burst"
        case .ambience: return "cloud.fill"
        }
    }
}

// MARK: - Container

struct AudioVisualizerView: View {
    let theme: VisualizerTheme
    var isPlaying: Bool = true

    var body: some View {
        switch theme {
        case .bars:     BarsVisualization(paused: !isPlaying)
        case .alchemy:  AlchemyVisualization(paused: !isPlaying)
        case .battery:  BatteryVisualization(paused: !isPlaying)
        case .spikes:   SpikesVisualization(paused: !isPlaying)
        case .ambience: AmbienceVisualization(paused: !isPlaying)
        }
    }
}

// MARK: - Bars & Waves

private struct BarsVisualization: View {
    let paused: Bool

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let barCount = 44
                let gap: CGFloat = 1.5
                let barW = (size.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
                let centerY = size.height / 2

                // Background
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                for i in 0..<barCount {
                    let phase = Double(i) / Double(barCount)

                    // Layered sin waves → pseudo-random bar heights
                    let w1 = sin(t * 2.1 + phase * .pi * 4.0) * 0.35
                    let w2 = sin(t * 3.7 + phase * .pi * 8.0) * 0.25
                    let w3 = sin(t * 5.3 + phase * .pi * 3.0) * 0.15
                    let envelope = sin(phase * .pi)    // taller bars toward center
                    let ratio = max(0.02, (w1 + w2 + w3 + 0.75) * envelope / 1.5)
                    let barH = ratio * size.height * 0.88

                    let x = CGFloat(i) * (barW + gap)
                    let rect = CGRect(x: x, y: centerY - barH / 2, width: barW, height: barH)

                    // Color: purple at base → hot-pink toward top
                    let hue = 0.78 - 0.28 * ratio
                    let color = Color(hue: hue, saturation: 0.9, brightness: 0.7 + 0.3 * ratio)

                    ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                }

                // Horizontal center line
                var line = Path()
                line.move(to: CGPoint(x: 0, y: centerY))
                line.addLine(to: CGPoint(x: size.width, y: centerY))
                ctx.stroke(line, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
            }
        }
        .background(Color.black)
    }
}

// MARK: - Alchemy

private struct AlchemyVisualization: View {
    let paused: Bool

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let minDim = min(size.width, size.height)

                ctx.blendMode = .screen

                let blobCount = 6
                for b in 0..<blobCount {
                    let db = Double(b)
                    let speed = 0.38 + db * 0.11
                    let angle = t * speed + db * (2.0 * .pi / Double(blobCount))
                    let orbit = minDim * (0.22 + 0.04 * sin(t * 0.31 + db))

                    let bx = center.x + cos(angle) * orbit
                    let by = center.y + sin(angle * 1.25 + db * 0.5) * orbit
                    let radius = minDim * (0.30 + 0.07 * sin(t * 0.6 + db * 1.1))

                    let hue = (db / Double(blobCount) + t * 0.04).truncatingRemainder(dividingBy: 1.0)
                    let blobColor = Color(hue: hue, saturation: 1.0, brightness: 1.0)

                    let ellipseRect = CGRect(
                        x: bx - radius, y: by - radius,
                        width: radius * 2, height: radius * 2
                    )
                    ctx.fill(
                        Path(ellipseIn: ellipseRect),
                        with: .radialGradient(
                            Gradient(colors: [blobColor.opacity(0.85), .clear]),
                            center: CGPoint(x: bx, y: by),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .background(Color.black)
    }
}

// MARK: - Battery

private struct BatteryVisualization: View {
    let paused: Bool

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                let cols = 22
                let rows = 22
                let cellW = size.width / CGFloat(cols)
                let cellH = size.height / CGFloat(rows)
                let cx = size.width / 2
                let cy = size.height / 2

                for col in 0..<cols {
                    for row in 0..<rows {
                        let px = (Double(col) + 0.5) * Double(cellW)
                        let py = (Double(row) + 0.5) * Double(cellH)

                        let dx = (px - Double(cx)) / Double(cx)
                        let dy = (py - Double(cy)) / Double(cy)
                        let dist = sqrt(dx * dx + dy * dy)

                        // Expanding ripple from center
                        let wave = sin(dist * 9.5 - t * 4.8)
                        let brightness = max(0.0, wave)
                        guard brightness > 0.05 else { continue }

                        // Neon green → teal gradient by distance
                        let hue = 0.37 + 0.1 * dist
                        let color = Color(hue: hue, saturation: 1.0, brightness: brightness)

                        let dotR = cellW * 0.38 * CGFloat(brightness)
                        let rect = CGRect(
                            x: CGFloat(px) - dotR,
                            y: CGFloat(py) - dotR,
                            width: dotR * 2, height: dotR * 2
                        )
                        ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .background(Color.black)
    }
}

// MARK: - Spikes

private struct SpikesVisualization: View {
    let paused: Bool

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let minDim = min(size.width, size.height)
                let spikeCount = 128
                let rotation = t * 0.07  // slow global rotation

                for i in 0..<spikeCount {
                    let di = Double(i)
                    let angle = di / Double(spikeCount) * 2.0 * .pi + rotation

                    // Animated spike length using harmonics
                    let base = minDim * 0.06
                    let h1 = max(0, sin(t * 2.6 + di * 0.28)) * minDim * 0.25
                    let h2 = max(0, sin(t * 4.2 + di * 0.65)) * minDim * 0.14
                    let length = base + h1 + h2

                    let dx = cos(angle)
                    let dy = sin(angle)

                    let start = CGPoint(
                        x: center.x + dx * minDim * 0.04,
                        y: center.y + dy * minDim * 0.04
                    )
                    let end = CGPoint(
                        x: center.x + dx * length,
                        y: center.y + dy * length
                    )

                    let normalized = min(1.0, (length - base) / (minDim * 0.39))
                    // Warm orange/yellow hue varies by index
                    let hue = (di / Double(spikeCount) * 0.12 + 0.06).truncatingRemainder(dividingBy: 0.18)
                    let color = Color(hue: hue, saturation: 1.0, brightness: 0.5 + 0.5 * normalized)

                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    ctx.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: max(0.5, 1.4 * CGFloat(normalized)), lineCap: .round)
                    )
                }

                // Pulsing center glow
                let glowR = minDim * (0.04 + 0.02 * sin(t * 3.5))
                let glowRect = CGRect(
                    x: center.x - glowR, y: center.y - glowR,
                    width: glowR * 2, height: glowR * 2
                )
                ctx.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [Color(hue: 0.1, saturation: 0.8, brightness: 1.0).opacity(0.9), .clear]),
                        center: center, startRadius: 0, endRadius: glowR
                    )
                )
            }
        }
        .background(Color.black)
    }
}

// MARK: - Ambience

private struct AmbienceVisualization: View {
    let paused: Bool

    private let blobColors: [Color] = [
        Color(hue: 0.62, saturation: 0.9, brightness: 0.9),   // deep blue
        Color(hue: 0.50, saturation: 1.0, brightness: 0.85),  // teal
        Color(hue: 0.80, saturation: 0.85, brightness: 0.9),  // violet
        Color(hue: 0.90, saturation: 0.85, brightness: 0.85), // magenta
    ]

    var body: some View {
        TimelineView(.animation(paused: paused)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let minDim = min(size.width, size.height)

                ctx.blendMode = .screen

                for (b, blobColor) in blobColors.enumerated() {
                    let db = Double(b)
                    let speed = 0.11 + db * 0.055
                    let angle = t * speed + db * (2.0 * .pi / Double(blobColors.count))
                    let drift = minDim * 0.13

                    let bx = center.x + cos(angle) * drift
                    let by = center.y + sin(angle * 1.4) * drift
                    let radius = minDim * (0.72 + 0.08 * sin(t * 0.18 + db))

                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: bx - radius, y: by - radius,
                            width: radius * 2, height: radius * 2
                        )),
                        with: .radialGradient(
                            Gradient(colors: [blobColor.opacity(0.45), .clear]),
                            center: CGPoint(x: bx, y: by),
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .background(Color.black)
    }
}
