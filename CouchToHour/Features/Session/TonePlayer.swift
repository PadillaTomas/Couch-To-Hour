import AudioToolbox
import AVFoundation
import CoreHaptics

/// The timer's out-of-screen feedback — sound plus haptics. A protocol so the
/// timer engine can be driven silently in tests.
protocol TonePlaying {
    /// A short tick — played at 3, 2, 1 seconds before a phase ends.
    func countdownTick()
    /// A distinct cue at the moment a phase changes (run → walk or walk → run).
    func phaseChange()
    /// The session reached its end.
    func sessionFinished()
    /// The session screen appeared — real players grab the audio session here.
    func sessionDidBegin()
    /// The session screen went away — real players release the audio session.
    func sessionDidEnd()
}

extension TonePlaying {
    /// Default: the end is just another phase boundary. Real players override
    /// with a more final cue.
    func sessionFinished() { phaseChange() }
    func sessionDidBegin() {}
    func sessionDidEnd() {}
}

/// Plays synthesised tones through the `.playback` audio session — loud, riding
/// the media-volume buttons, heard even with the ringer muted — and fires
/// Core Haptics patterns strong enough to feel with the phone in a pocket.
///
/// Not unit-tested: audio and haptics are device-only. Tests drive the timer
/// with ``SilentTonePlayer`` / a spy.
final class SessionCuePlayer: TonePlaying {

    /// When `true`, other apps' audio (music, podcasts) is briefly dipped under
    /// each cue. When `false`, cues layer on top at full volume.
    private let dimsOtherAudio: Bool

    init(dimsOtherAudio: Bool = true) {
        self.dimsOtherAudio = dimsOtherAudio
    }

    // MARK: Sound — short sine bursts, generated once, volume 1.0

    private lazy var tickPlayer = ToneSynth.player([(880, 0.07)], volume: 0.85)
    private lazy var changePlayer = ToneSynth.player([(784, 0.13), (1175, 0.16)], volume: 1)
    private lazy var donePlayer = ToneSynth.player([(659, 0.13), (880, 0.13), (1319, 0.28)], volume: 1)

    private func play(_ player: AVAudioPlayer?) {
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }

    // MARK: Haptics — one strong sustained buzz per cue (not delicate taps).
    // Core Haptics continuous at full intensity; the classic system vibration
    // as a fallback on devices without Core Haptics.

    private let hapticsSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    private func startHaptics() {
        guard hapticsSupported else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = false
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            self.engine = nil
        }
    }

    private func stopHaptics() {
        engine?.stop()
        engine = nil
    }

    /// A full-strength rumble of `duration` seconds, repeated `count` times with
    /// a short gap. Low sharpness → it reads as a vibration, not a click.
    private func vibrate(seconds: TimeInterval, count: Int = 1) {
        guard let engine else {
            for i in 0..<count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.55) {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                }
            }
            return
        }
        let events = (0..<count).map { i in
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            ], relativeTime: Double(i) * (seconds + 0.12), duration: seconds)
        }
        do {
            try engine.start()   // no-op if running; recovers after a background trip
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    // MARK: TonePlaying

    func countdownTick() {
        play(tickPlayer)   // sound only — a buzz every second is too much
    }

    func phaseChange() {
        play(changePlayer)
        vibrate(seconds: 0.5)
    }

    func sessionFinished() {
        play(donePlayer)
        vibrate(seconds: 0.4, count: 3)
    }

    func sessionDidBegin() {
        // `.playback` ignores the mute switch; `.mixWithOthers` keeps the
        // runner's music going alongside our cues, optionally ducked under them.
        var options: AVAudioSession.CategoryOptions = [.mixWithOthers]
        if dimsOtherAudio { options.insert(.duckOthers) }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: options)
        try? session.setActive(true)

        [tickPlayer, changePlayer, donePlayer].forEach { $0?.prepareToPlay() }   // synth now
        startHaptics()
    }

    func sessionDidEnd() {
        stopHaptics()
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// No-op — the default in tests and previews.
struct SilentTonePlayer: TonePlaying {
    func countdownTick() {}
    func phaseChange() {}
}

// MARK: - Tone synthesis

/// Builds a tiny in-memory WAV of one or more sine notes played back-to-back,
/// each with a click-free attack/decay envelope. No bundled audio assets.
enum ToneSynth {
    static func player(_ notes: [(frequency: Double, seconds: Double)],
                       volume: Float,
                       sampleRate: Double = 44_100) -> AVAudioPlayer? {
        var samples: [Int16] = []
        for note in notes {
            let count = Int(sampleRate * note.seconds)
            let attack = max(1, Int(sampleRate * 0.004))
            let release = max(1, Int(sampleRate * 0.02))
            for i in 0..<count {
                let t = Double(i) / sampleRate
                var amp = sin(2 * .pi * note.frequency * t)
                if i < attack { amp *= Double(i) / Double(attack) }
                if i > count - release { amp *= Double(count - i) / Double(release) }
                samples.append(Int16(amp * 30_000))
            }
        }
        guard let data = wav(samples: samples, sampleRate: Int(sampleRate)),
              let player = try? AVAudioPlayer(data: data)
        else { return nil }
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    private static func wav(samples: [Int16], sampleRate: Int) -> Data? {
        guard !samples.isEmpty else { return nil }
        let dataSize = samples.count * 2
        var d = Data()
        func str(_ s: String) { d.append(s.data(using: .ascii)!) }
        func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { d.append(contentsOf: $0) } }

        str("RIFF"); u32(36 + dataSize); str("WAVE")
        str("fmt "); u32(16); u16(1); u16(1)           // PCM, mono
        u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16)
        str("data"); u32(dataSize)
        samples.withUnsafeBufferPointer { d.append(Data(buffer: $0)) }
        return d
    }
}
