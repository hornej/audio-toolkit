import SwiftUI

struct SpectrumPlotView: View {
    let spectrum: [Float]
    let frequencies: [Float]
    let minHz: Double
    let maxHz: Double
    var minDB: Float = -120
    var maxDB: Float = 0
    private let plotInset: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let plotSize = CGSize(
                width: max(0, geometry.size.width - (plotInset * 2)),
                height: max(0, geometry.size.height - (plotInset * 2))
            )
            let points = spectrumPoints(size: plotSize)

            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                gridPath(size: plotSize)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.teal, lineWidth: 2)
                }
            }
            .frame(width: plotSize.width, height: plotSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func spectrumPoints(size: CGSize) -> [CGPoint] {
        guard size.width > 0, size.height > 0 else { return [] }
        guard minHz < maxHz else { return [] }
        let count = min(spectrum.count, frequencies.count)
        guard count > 0 else { return [] }

        let minHzFloat = Float(minHz)
        let maxHzFloat = Float(maxHz)
        let dbSpan = maxDB - minDB
        guard dbSpan > 0 else { return [] }

        var filteredCount = 0
        for index in 0..<count {
            let freq = frequencies[index]
            if freq >= minHzFloat && freq <= maxHzFloat {
                filteredCount += 1
            }
        }
        guard filteredCount > 0 else { return [] }

        let targetPoints = max(32, Int(size.width))
        let step = max(1, filteredCount / targetPoints)

        var points: [CGPoint] = []
        points.reserveCapacity(filteredCount / step + 1)

        let hzSpan = maxHz - minHz
        var seen = 0
        for index in 0..<count {
            let freq = frequencies[index]
            guard freq >= minHzFloat && freq <= maxHzFloat else { continue }
            if seen % step == 0 {
                let x = CGFloat((Double(freq) - minHz) / hzSpan) * size.width
                let clampedDb = min(max(spectrum[index], minDB), maxDB)
                let normalized = (clampedDb - minDB) / dbSpan
                let y = size.height - CGFloat(normalized) * size.height
                points.append(CGPoint(x: x, y: y))
            }
            seen += 1
        }

        return points
    }

    private func gridPath(size: CGSize) -> Path {
        var path = Path()
        let columns = 4
        let rows = 4

        for column in 0...columns {
            let x = size.width * CGFloat(column) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }

        for row in 0...rows {
            let y = size.height * CGFloat(row) / CGFloat(rows)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }

        return path
    }
}
