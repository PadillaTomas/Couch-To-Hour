import AudioToolbox

/// The timer's audio cues. A protocol so the timer engine can be driven
/// silently in tests.
protocol TonePlaying {
    /// A short tick — played at 3, 2, 1 seconds before a phase ends.
    func countdownTick()
    /// A distinct tone at the moment a phase changes (run → walk or walk → run).
    func phaseChange()
}

/// Plays iOS system sounds. No `AVAudioSession` juggling — this is for a session
/// the user is actively watching; MVP scope has no background audio.
struct SystemTonePlayer: TonePlaying {
    // System sound IDs — swap freely; these are placeholders picked for feel.
    private let tickID: SystemSoundID = 1104          // "Tock"
    private let changeID: SystemSoundID = 1113        // "begin_record"

    func countdownTick() { AudioServicesPlaySystemSound(tickID) }
    func phaseChange() { AudioServicesPlaySystemSound(changeID) }
}

/// No-op — the default in tests and previews.
struct SilentTonePlayer: TonePlaying {
    func countdownTick() {}
    func phaseChange() {}
}
