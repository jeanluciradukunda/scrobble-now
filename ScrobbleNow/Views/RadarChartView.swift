import SwiftUI

struct RadarChartView: View {
    /// Each axis: (label, currentValue, maxValue)
    let axes: [(String, Double, Double)]
    let threshold: Double
    let maxTotal: Double

    private let gridLevels = 4
    private var accentColor: Color { AppAccent.current }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 30

            ZStack {
                // Grid rings
                ForEach(1...gridLevels, id: \.self) { level in
                    let fraction = Double(level) / Double(gridLevels)
                    polygonPath(center: center, radius: radius * fraction, sides: axes.count)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }

                // Axis lines
                ForEach(0..<axes.count, id: \.self) { i in
                    let angle = angleFor(index: i)
                    let end = pointAt(center: center, radius: radius, angle: angle)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: end)
                    }
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                }

                // Threshold ring
                let thresholdFraction = threshold / maxTotal
                polygonPath(center: center, radius: radius * thresholdFraction, sides: axes.count)
                    .stroke(Color.red.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // Data polygon (filled)
                dataPath(center: center, radius: radius)
                    .fill(accentColor.opacity(0.15))

                // Data polygon (stroke)
                dataPath(center: center, radius: radius)
                    .stroke(accentColor, lineWidth: 1.5)

                // Data points
                ForEach(0..<axes.count, id: \.self) { i in
                    let (_, value, maxVal) = axes[i]
                    let fraction = value / maxVal
                    let angle = angleFor(index: i)
                    let point = pointAt(center: center, radius: radius * fraction, angle: angle)

                    Circle()
                        .fill(accentColor)
                        .frame(width: 5, height: 5)
                        .position(point)

                    // Value label near the point
                    Text("\(Int(value))")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .position(pointAt(center: center, radius: radius * fraction + 10, angle: angle))
                }

                // Axis labels
                ForEach(0..<axes.count, id: \.self) { i in
                    let (label, _, _) = axes[i]
                    let angle = angleFor(index: i)
                    let labelPos = pointAt(center: center, radius: radius + 20, angle: angle)

                    Text(label)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .position(labelPos)
                }

                // Threshold label
                VStack(spacing: 1) {
                    Text("MIN")
                        .font(.system(size: 6, weight: .bold))
                    Text("\(Int(threshold))")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.red.opacity(0.6))
                .position(x: center.x + radius * thresholdFraction + 16, y: center.y - 8)

                // Total score
                let total = axes.reduce(0) { $0 + $1.1 }
                VStack(spacing: 1) {
                    Text("TOTAL")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(.tertiary)
                    Text("\(Int(total))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(total >= threshold ? accentColor : .red)
                }
                .position(center)
            }
        }
    }

    // MARK: - Geometry

    private func angleFor(index: Int) -> Double {
        let slice = (2 * .pi) / Double(axes.count)
        return slice * Double(index) - .pi / 2 // Start from top
    }

    private func pointAt(center: CGPoint, radius: Double, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private func polygonPath(center: CGPoint, radius: Double, sides: Int) -> Path {
        Path { path in
            for i in 0...sides {
                let angle = angleFor(index: i % sides)
                let point = pointAt(center: center, radius: radius, angle: angle)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }

    private func dataPath(center: CGPoint, radius: Double) -> Path {
        Path { path in
            for i in 0...axes.count {
                let idx = i % axes.count
                let (_, value, maxVal) = axes[idx]
                let fraction = value / maxVal
                let angle = angleFor(index: idx)
                let point = pointAt(center: center, radius: radius * fraction, angle: angle)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }
}
