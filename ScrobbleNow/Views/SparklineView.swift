import SwiftUI

/// Minimal sparkline chart for metric history
struct SparklineView: View {
    let data: [Double]
    let color: Color
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            if data.count > 1 {
                let maxVal = max(data.max() ?? 1, 1)
                let minVal = data.min() ?? 0
                let range = max(maxVal - minVal, 0.1)

                ZStack(alignment: .bottom) {
                    // Fill gradient
                    Path { path in
                        let stepX = geo.size.width / CGFloat(data.count - 1)

                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        for (i, val) in data.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = geo.size.height - CGFloat((val - minVal) / range) * geo.size.height
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        let stepX = geo.size.width / CGFloat(data.count - 1)

                        for (i, val) in data.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = geo.size.height - CGFloat((val - minVal) / range) * geo.size.height
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, lineWidth: 1)

                    // Current value dot
                    if let last = data.last {
                        let x = geo.size.width
                        let y = geo.size.height - CGFloat((last - minVal) / range) * geo.size.height
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .position(x: x, y: y)
                    }
                }
            } else {
                Rectangle()
                    .fill(color.opacity(0.05))
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
