# Audio Toolkit

`Audio Toolkit` is a small SwiftUI iOS app for live audio spectrum analysis.
It listens to the device microphone, runs an FFT on incoming audio, and shows
the current spectrum together with the strongest frequencies in the selected
range.

## What It Does

- Captures microphone input with `AVAudioEngine`
- Computes a live spectrum with `Accelerate`/`vDSP`
- Displays the spectrum in a simple SwiftUI plot
- Lets you adjust the visible frequency range
- Lets you adjust the dB floor for the chart
- Shows the top detected peaks in the current range
- Supports tap-to-freeze on the spectrum view

## Requirements

- Xcode 17+
- iOS 26.2+ (current project deployment target)
- A device or simulator build environment with microphone permission support

## Running The App

### In Xcode

1. Open `audio-toolkit.xcodeproj`
2. Select the `audio-toolkit` scheme
3. Choose an iPhone simulator or connected device
4. Build and run

### From The Command Line

```bash
xcodebuild -project audio-toolkit.xcodeproj -scheme audio-toolkit -destination 'platform=iOS Simulator,name=iPhone 17' build
```

For real audio input, running on a physical device is usually more useful than
the simulator.

For device installs, set your own signing team and bundle identifier in Xcode if
needed.

## Using The App

- Grant microphone access when prompted
- Watch the live spectrum update in real time
- Tap the plot to freeze or unfreeze the current spectrum
- Set the minimum and maximum frequency range in Hz
- Adjust the chart floor with the dB slider
- Review the top detected frequencies in the selected range

The valid maximum frequency is limited by the current input sample rate
(`Nyquist = sampleRate / 2`).

## Project Structure

- `audio-toolkit/audio_toolkitApp.swift`: app entry point
- `audio-toolkit/ContentView.swift`: main UI and interaction logic
- `audio-toolkit/AudioSpectrumAnalyzer.swift`: microphone capture and FFT processing
- `audio-toolkit/SpectrumPlotView.swift`: spectrum rendering
- `audio-toolkit/YAxisView.swift`: dB axis labels
- `audio-toolkit/TapSlider.swift`: slider used for dB floor control

## Notes

- If microphone permission is denied, the app shows a message instead of the analyzer UI.
- The current FFT size is `4096`.
- There are no automated tests in the repo at the moment.
