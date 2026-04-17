import AVFoundation
import Accelerate
import Combine

final class AudioSpectrumAnalyzer: ObservableObject {
    @Published var spectrum: [Float] = []
    @Published var binFrequencies: [Float] = []
    @Published var sampleRate: Double = 44100
    @Published var isRunning = false
    @Published var permissionDenied = false
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "AudioSpectrumAnalyzer.processing")
    private let fftSize: Int
    private let log2n: vDSP_Length
    private var fftSetup: FFTSetup?
    private var window: [Float]
    private var windowed: [Float]
    private var real: [Float]
    private var imag: [Float]
    private var magnitudes: [Float]
    private var dbValues: [Float]
    private var lastSampleRate: Double = 0
    private var shouldBeRunning = false
    private var hasInstalledTap = false

    init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.windowed = [Float](repeating: 0, count: fftSize)
        let binCount = fftSize / 2
        self.real = [Float](repeating: 0, count: binCount)
        self.imag = [Float](repeating: 0, count: binCount)
        self.magnitudes = [Float](repeating: 0, count: binCount)
        self.dbValues = [Float](repeating: 0, count: binCount)
        self.fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
    }

    deinit {
        stop()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    func start() {
        shouldBeRunning = true
        guard !isRunning else { return }
        guard fftSetup != nil else {
            errorMessage = "FFT setup failed."
            return
        }
        errorMessage = nil

        requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.permissionDenied = !granted
                guard granted, self.shouldBeRunning else { return }
                self.startEngine()
            }
        }
    }

    func stop() {
        shouldBeRunning = false
        if hasInstalledTap {
            engine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        if engine.isRunning {
            engine.stop()
        }
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    private func startEngine() {
        guard shouldBeRunning else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Audio session error: \(error.localizedDescription)"
            }
            return
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate

        processingQueue.async {
            self.configureSpectrumAxis(sampleRate: sampleRate)
        }

        if hasInstalledTap {
            input.removeTap(onBus: 0)
        }
        input.installTap(onBus: 0,
                         bufferSize: AVAudioFrameCount(fftSize),
                         format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard let channelData = buffer.floatChannelData?.pointee else { return }
            let frameCount = Int(buffer.frameLength)
            let sampleCount = min(frameCount, self.fftSize)
            var samples = [Float](repeating: 0, count: self.fftSize)
            samples.withUnsafeMutableBufferPointer { dest in
                dest.baseAddress?.update(from: channelData, count: sampleCount)
            }
            self.processingQueue.async {
                self.process(samples: samples, sampleRate: sampleRate)
            }
        }
        hasInstalledTap = true

        engine.prepare()
        do {
            try engine.start()
            DispatchQueue.main.async {
                self.errorMessage = nil
                self.isRunning = true
            }
        } catch {
            input.removeTap(onBus: 0)
            hasInstalledTap = false
            DispatchQueue.main.async {
                self.errorMessage = "Audio engine error: \(error.localizedDescription)"
            }
        }
    }

    private func configureSpectrumAxis(sampleRate: Double) {
        lastSampleRate = sampleRate
        let binCount = fftSize / 2
        let frequencies = (0..<binCount).map { index in
            Float(Double(index) * sampleRate / Double(fftSize))
        }
        DispatchQueue.main.async {
            self.sampleRate = sampleRate
            self.binFrequencies = frequencies
        }
    }

    private func process(samples: [Float], sampleRate: Double) {
        if sampleRate != lastSampleRate {
            configureSpectrumAxis(sampleRate: sampleRate)
        }
        guard let setup = fftSetup else { return }

        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        let binCount = fftSize / 2
        real.withUnsafeMutableBufferPointer { realPointer in
            imag.withUnsafeMutableBufferPointer { imagPointer in
                var splitComplex = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                windowed.withUnsafeBufferPointer { windowedPointer in
                    windowedPointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: binCount) { complexPointer in
                        vDSP_ctoz(complexPointer, 2, &splitComplex, 1, vDSP_Length(binCount))
                    }
                }

                vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                var scale = 1.0 / Float(fftSize)
                vDSP_vsmul(splitComplex.realp, 1, &scale, splitComplex.realp, 1, vDSP_Length(binCount))
                vDSP_vsmul(splitComplex.imagp, 1, &scale, splitComplex.imagp, 1, vDSP_Length(binCount))

                magnitudes[0] = abs(splitComplex.realp[0])
                if binCount > 1 {
                    var splitSlice = DSPSplitComplex(
                        realp: splitComplex.realp.advanced(by: 1),
                        imagp: splitComplex.imagp.advanced(by: 1)
                    )
                    vDSP_zvabs(&splitSlice, 1, &magnitudes[1], 1, vDSP_Length(binCount - 1))
                }
            }
        }

        var epsilon: Float = 1.0e-7
        vDSP_vsadd(magnitudes, 1, &epsilon, &magnitudes, 1, vDSP_Length(binCount))
        var reference: Float = 1.0
        vDSP_vdbcon(magnitudes, 1, &reference, &dbValues, 1, vDSP_Length(binCount), 1)

        let spectrumSnapshot = dbValues

        DispatchQueue.main.async {
            self.spectrum = spectrumSnapshot
        }
    }

    private func requestRecordPermission(_ handler: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                handler(granted)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                handler(granted)
            }
        }
    }
}
