import SwiftUI

struct TopFrequency: Identifiable {
    let id: Int
    let frequency: Double
    let db: Float
}

struct ContentView: View {
    @StateObject private var analyzer = AudioSpectrumAnalyzer()
    @State private var minFrequency: Double = 20
    @State private var maxFrequency: Double = 20000
    @State private var minFrequencyText: String = "20"
    @State private var maxFrequencyText: String = "20000"
    @State private var yMinDb: Float = -120
    @State private var isFrozen = false
    @State private var frozenSpectrum: [Float] = []
    @State private var frozenFrequencies: [Float] = []
    @FocusState private var focusedField: FrequencyField?

    private enum FrequencyField {
        case min
        case max
    }

    private let plotHeight: CGFloat = 220

    private var statusText: String {
        isFrozen ? "Frozen" : (analyzer.isRunning ? "Listening" : "Stopped")
    }

    private var statusColor: Color {
        isFrozen ? .orange : (analyzer.isRunning ? .green : .gray)
    }

    private var topResults: [TopFrequency] {
        topFrequencies(spectrum: displayedSpectrum, frequencies: displayedFrequencies)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Audio Spectrum")
                    .font(.title2)
                    .bold()

                if analyzer.permissionDenied {
                    Text("Microphone access is off. Enable it in Settings to use the spectrum analyzer.")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        YAxisView(minDB: yMinDb, maxDB: 0, step: 10)
                            .frame(width: 60, height: plotHeight)

                        SpectrumPlotView(
                            spectrum: displayedSpectrum,
                            frequencies: displayedFrequencies,
                            minHz: minFrequency,
                            maxHz: maxFrequency,
                            minDB: yMinDb
                        )
                        .frame(height: plotHeight)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: toggleFreeze)
                    }

                    HStack {
                        Text(formattedFrequency(minFrequency))
                        Spacer()
                        Text(formattedFrequency((minFrequency + maxFrequency) / 2))
                        Spacer()
                        Text(formattedFrequency(maxFrequency))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("X Axis Range (Hz)")
                            .font(.headline)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("20", text: $minFrequencyText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .min)
                                    .submitLabel(.done)
                                    .onSubmit(applyRangeFromText)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Max")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("20000", text: $maxFrequencyText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .max)
                                    .submitLabel(.done)
                                    .onSubmit(applyRangeFromText)
                            }
                        }

                        Text("Current range: \(formattedFrequency(minFrequency)) to \(formattedFrequency(maxFrequency))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Y Axis Floor (dB)")
                            .font(.headline)

                        TapSlider(value: $yMinDb, range: -120 ... -50, step: 10)

                        Text("Min dB: \(String(format: "%.0f dB", yMinDb))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Frequencies (Selected Range)")
                            .font(.headline)

                        if topResults.isEmpty {
                            Text("Listening...")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(topResults) { item in
                                HStack {
                                    Text(formattedFrequency(item.frequency))
                                    Spacer()
                                    Text(String(format: "%.1f dB", item.db))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let errorMessage = analyzer.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
        }
        .onAppear {
            handleAppear()
        }
        .onDisappear {
            analyzer.stop()
        }
        .onChange(of: analyzer.sampleRate) { _, _ in
            handleSampleRateChange()
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue == nil {
                applyRangeFromText()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: dismissKeyboard)
            }
        }
    }

    private var maxAllowedFrequency: Double {
        let nyquist = max(20, analyzer.sampleRate / 2)
        return min(20000, nyquist)
    }

    private var displayedSpectrum: [Float] {
        if isFrozen {
            return frozenSpectrum.isEmpty ? analyzer.spectrum : frozenSpectrum
        }
        return analyzer.spectrum
    }

    private var displayedFrequencies: [Float] {
        if isFrozen {
            return frozenFrequencies.isEmpty ? analyzer.binFrequencies : frozenFrequencies
        }
        return analyzer.binFrequencies
    }

    private func clampRange() {
        let minAllowed = 20.0
        let maxAllowed = maxAllowedFrequency
        if maxAllowed <= minAllowed {
            minFrequency = minAllowed
            maxFrequency = maxAllowed
            return
        }
        if minFrequency < minAllowed {
            minFrequency = minAllowed
        }
        if maxFrequency < minAllowed + 1 {
            maxFrequency = minAllowed + 1
        }
        if maxFrequency > maxAllowed {
            maxFrequency = maxAllowed
        }
        if minFrequency >= maxFrequency {
            minFrequency = max(minAllowed, maxFrequency - 1)
        }
    }

    private func applyRangeFromText() {
        let newMin = parseFrequency(minFrequencyText) ?? minFrequency
        let newMax = parseFrequency(maxFrequencyText) ?? maxFrequency
        minFrequency = newMin
        maxFrequency = newMax
        clampRange()
        syncTextWithValues()
    }

    private func syncTextWithValues() {
        minFrequencyText = String(Int(round(minFrequency)))
        maxFrequencyText = String(Int(round(maxFrequency)))
    }

    private func parseFrequency(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(sanitized)
    }

    private func toggleFreeze() {
        if isFrozen {
            isFrozen = false
            frozenSpectrum = []
            frozenFrequencies = []
        } else {
            frozenSpectrum = analyzer.spectrum
            frozenFrequencies = analyzer.binFrequencies
            isFrozen = true
        }
    }

    private func handleAppear() {
        clampRange()
        syncTextWithValues()
        analyzer.start()
    }

    private func handleSampleRateChange() {
        clampRange()
        if focusedField == nil {
            syncTextWithValues()
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private func topFrequencies(spectrum: [Float], frequencies: [Float]) -> [TopFrequency] {
        let count = min(spectrum.count, frequencies.count)
        guard count > 0 else { return [] }

        let minHz = Float(minFrequency)
        let maxHz = Float(maxFrequency)

        var indicesInRange: [Int] = []
        var dbValuesInRange: [Float] = []
        indicesInRange.reserveCapacity(count)
        dbValuesInRange.reserveCapacity(count)

        for index in 0..<count {
            let freq = frequencies[index]
            guard freq >= minHz && freq <= maxHz else { continue }
            indicesInRange.append(index)
            dbValuesInRange.append(spectrum[index])
        }

        guard !indicesInRange.isEmpty else { return [] }

        let noiseFloor = percentile(of: dbValuesInRange, 0.2)
        let threshold = noiseFloor + 6

        var peaks: [(index: Int, db: Float)] = []
        peaks.reserveCapacity(8)

        for index in indicesInRange {
            guard index > 0 && index < count - 1 else { continue }
            let value = spectrum[index]
            guard value >= threshold else { continue }
            let left = spectrum[index - 1]
            let right = spectrum[index + 1]
            if value > left && value >= right {
                peaks.append((index, value))
            }
        }

        peaks.sort { $0.db > $1.db }

        var results: [TopFrequency] = []
        results.reserveCapacity(3)
        var usedLabels = Set<String>()

        for peak in peaks {
            let freq = Double(frequencies[peak.index])
            let label = formattedFrequency(freq)
            guard !usedLabels.contains(label) else { continue }
            usedLabels.insert(label)
            results.append(TopFrequency(id: results.count, frequency: freq, db: peak.db))
            if results.count == 3 { break }
        }

        if results.isEmpty {
            var maxCandidate: (index: Int, db: Float)?
            for index in indicesInRange {
                let value = spectrum[index]
                guard value >= threshold else { continue }
                if maxCandidate == nil || value > maxCandidate!.db {
                    maxCandidate = (index, value)
                }
            }
            if let candidate = maxCandidate {
                let freq = Double(frequencies[candidate.index])
                results.append(TopFrequency(id: 0, frequency: freq, db: candidate.db))
            }
        }

        return results
    }

    private func percentile(of values: [Float], _ percentile: Float) -> Float {
        guard !values.isEmpty else { return 0 }
        let clamped = min(max(percentile, 0), 1)
        let sorted = values.sorted()
        let position = Float(sorted.count - 1) * clamped
        let index = max(0, min(sorted.count - 1, Int(position)))
        return sorted[index]
    }

    private func formattedFrequency(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1f kHz", value / 1000)
        }
        return String(format: "%.0f Hz", value)
    }
}

#Preview {
    ContentView()
}
