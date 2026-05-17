import AVFoundation
import Combine
import SwiftUI

// MARK: - Timer Sound

enum TimerSound: String, CaseIterable {
    case chime
    case bright
    case deep

    var displayName: String {
        switch self {
        case .chime: return "Chime"
        case .bright: return "Bright"
        case .deep: return "Deep"
        }
    }

    /// Frequency (Hz) of the sine wave for this sound.
    var frequency: Double {
        switch self {
        case .chime: return 880
        case .bright: return 1200
        case .deep: return 523
        }
    }

    /// Duration (seconds) of the generated tone.
    var toneDuration: Double {
        switch self {
        case .chime: return 0.25
        case .bright: return 0.18
        case .deep: return 0.35
        }
    }
}

// MARK: - Sound Manager

/// Manages audio session configuration, programmatic WAV generation,
/// and `AVAudioPlayer`-based playback of the finish sound.
///
/// The `.playback` audio-session category routes audio through the media
/// volume so the sound plays even when the hardware silent switch is on.
///
/// The finish sound is a short sine-wave tone played three times in
/// quick succession with a brief pause between each beep.
final class SoundManager: ObservableObject {

    // MARK: - Persisted Selection

    @AppStorage("selectedSound") private var selectedSoundRaw: String = TimerSound.chime.rawValue

    /// Bridges `@AppStorage` (which writes directly to `UserDefaults`)
    /// into `ObservableObject` so the settings sheet reactively updates.
    var selectedSound: TimerSound {
        get { TimerSound(rawValue: selectedSoundRaw) ?? .chime }
        set {
            objectWillChange.send()
            selectedSoundRaw = newValue.rawValue
        }
    }

    // MARK: - Private

    private var audioPlayer: AVAudioPlayer?

    private enum Playback {
        static let beepCount = 3
        static let beepInterval: TimeInterval = 0.35
        static let volume: Float = 1.0
        static let sampleRate: Double = 44100
        static let amplitude: Double = 1.0
    }

    private enum WAVHeader {
        static let bitsPerSample: UInt16 = 16
        static let audioFormatPCM: UInt16 = 1
        static let channelCount: UInt16 = 1
    }

    // MARK: - Lifecycle

    init() {
        configureAudioSession()
    }

    // MARK: - Audio Session

    /// Configures the shared `AVAudioSession` for media playback so the
    /// finish sound bypasses the silent switch and mixes with other audio.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Public API

    /// Generates (or reuses) the WAV for the selected sound, then plays
    /// it `beepCount` times in sequence.
    func playFinishSound() {
        guard let url = generateWAV(for: selectedSound) else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = Playback.volume
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to create audio player: \(error)")
            return
        }

        scheduleBeeps(remaining: Playback.beepCount)
    }

    // MARK: - Beep Sequencing

    /// Recursively schedules playback of one beep, then dispatches the
    /// next after `beepInterval` seconds.
    private func scheduleBeeps(remaining: Int) {
        guard remaining > 0 else { return }
        audioPlayer?.currentTime = 0
        audioPlayer?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + Playback.beepInterval) { [weak self] in
            self?.scheduleBeeps(remaining: remaining - 1)
        }
    }

    // MARK: - Programmatic WAV Generation

    /// Builds a valid RIFF WAV file in memory and writes it to a temporary
    /// URL so `AVAudioPlayer` can load it without bundled assets.
    ///
    /// The tone is a mono 16-bit PCM sine wave with a linear fade envelope
    /// that ramps from full amplitude to silence over the tone's duration.
    private func generateWAV(for sound: TimerSound) -> URL? {
        let sampleRate = Playback.sampleRate
        let duration = sound.toneDuration
        let frequency = sound.frequency

        let sampleCount = Int(sampleRate * duration)
        let dataByteCount = UInt32(sampleCount * 2)
        var data = Data()

        // ---- RIFF header ------------------------------------------------
        data.append(string: "RIFF")
        data.append(littleEndian: UInt32(36 + dataByteCount))
        data.append(string: "WAVE")

        // ---- fmt chunk --------------------------------------------------
        data.append(string: "fmt ")
        data.append(littleEndian: UInt32(16))
        data.append(littleEndian: WAVHeader.audioFormatPCM)
        data.append(littleEndian: WAVHeader.channelCount)
        data.append(littleEndian: UInt32(sampleRate))
        data.append(littleEndian: UInt32(sampleRate * 2))        // byte rate
        data.append(littleEndian: UInt16(2))                     // block align
        data.append(littleEndian: WAVHeader.bitsPerSample)

        // ---- data chunk ------------------------------------------------
        data.append(string: "data")
        data.append(littleEndian: dataByteCount)

        // ---- PCM samples -----------------------------------------------
        for i in 0 ..< sampleCount {
            let t = Double(i) / sampleRate
            let envelope = 1.0 - (t / duration)            // linear fade to zero
            let raw = sin(2 * .pi * frequency * t)
            let sample = Int16(raw * 32767 * Playback.amplitude * envelope)
            data.append(littleEndian: sample)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sound.rawValue).wav")
        try? data.write(to: url)
        return url
    }
}

// MARK: - Data Helpers

private extension Data {
    mutating func append(string: String) {
        guard let bytes = string.data(using: .ascii) else { return }
        append(bytes)
    }

    mutating func append<T>(littleEndian value: T) {
        var copy = value
        append(Data(bytes: &copy, count: MemoryLayout<T>.size))
    }
}
