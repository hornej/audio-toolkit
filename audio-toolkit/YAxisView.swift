import SwiftUI

struct YAxisView: View {
    let minDB: Float
    let maxDB: Float
    let step: Float

    var body: some View {
        GeometryReader { geometry in
            let ticks = tickValues()
            let width = geometry.size.width
            let tickLength: CGFloat = 6
            let labelPadding: CGFloat = 4
            let labelWidth = max(0, width - tickLength - labelPadding)

            ZStack(alignment: .topLeading) {
                ForEach(ticks, id: \.self) { value in
                    let y = yPosition(for: value, height: geometry.size.height)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: tickLength, height: 1)
                        .position(x: labelWidth + labelPadding + tickLength / 2, y: y)
                    Text(label(for: value))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: labelWidth, alignment: .trailing)
                        .position(x: labelWidth / 2, y: y)
                }
            }
        }
    }

    private func tickValues() -> [Float] {
        let stepValue = max(step, 1)
        var values: [Float] = []
        var current = maxDB
        while current >= minDB - 0.001 {
            values.append(current)
            current -= stepValue
        }
        if let last = values.last, last > minDB {
            values.append(minDB)
        }
        return values
    }

    private func yPosition(for value: Float, height: CGFloat) -> CGFloat {
        let span = maxDB - minDB
        guard span > 0, height > 0 else { return height }
        let normalized = (value - minDB) / span
        return height - CGFloat(normalized) * height
    }

    private func label(for value: Float) -> String {
        String(format: "%.0f dB", value)
    }
}
