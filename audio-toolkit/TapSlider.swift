import SwiftUI

struct TapSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let step: Float

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let clamped = normalizedValue(for: value)
            let knobSize: CGFloat = 18
            let trackHeight: CGFloat = 4

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: clamped * width, height: trackHeight)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: clamped * (width - knobSize))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let x = min(max(0, gesture.location.x), width)
                        let raw = Float(x / width) * (range.upperBound - range.lowerBound) + range.lowerBound
                        let stepped = stepValue(raw)
                        value = min(max(stepped, range.lowerBound), range.upperBound)
                    }
            )
        }
        .frame(height: 28)
    }

    private func normalizedValue(for value: Float) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let normalized = (value - range.lowerBound) / span
        return CGFloat(min(max(normalized, 0), 1))
    }

    private func stepValue(_ raw: Float) -> Float {
        guard step > 0 else { return raw }
        return (raw / step).rounded() * step
    }
}
