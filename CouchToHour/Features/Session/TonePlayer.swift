import AudioToolbox
import AVFoundation
import UIKit

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

/// Plays iOS system sounds through the `.playback` audio session — so cues are
/// heard even with the ringer muted — and fires matching haptics for when audio
/// is off or the earbuds are out.
final class SessionCuePlayer: TonePlaying {
    // System sound IDs — swap freely; these are placeholders picked for feel.
    private let tickID: SystemSoundID = 1104          // "Tock"
    private let changeID: SystemSoundID = 1113        // "begin_record"

    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let notify = UINotificationFeedbackGenerator()

    /// When `true`, other apps' audio (music, podcasts) is briefly dipped under
    /// each cue so the click is heard over it. When `false`, cues just layer on
    /// top at full volume.
    private let dimsOtherAudio: Bool

    init(dimsOtherAudio: Bool = true) {
        self.dimsOtherAudio = dimsOtherAudio
    }

    func countdownTick() {
        AudioServicesPlaySystemSound(tickID)
    }

    func phaseChange() {
        AudioServicesPlaySystemSound(changeID)
        impact.impactOccurred()
    }

    func sessionFinished() {
        AudioServicesPlaySystemSound(changeID)
        notify.notificationOccurred(.success)
    }

    func sessionDidBegin() {
        // `.playback` ignores the mute switch; `.mixWithOthers` keeps the
        // runner's music going alongside our cues, optionally ducked under them.
        var options: AVAudioSession.CategoryOptions = [.mixWithOthers]
        if dimsOtherAudio { options.insert(.duckOthers) }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: options)
        try? session.setActive(true)
        impact.prepare()
        notify.prepare()
    }

    func sessionDidEnd() {
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// No-op — the default in tests and previews.
struct SilentTonePlayer: TonePlaying {
    func countdownTick() {}
    func phaseChange() {}
}
