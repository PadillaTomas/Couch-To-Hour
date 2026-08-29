import Foundation
import UIWorkouts

/// Identifies the plan session a resume snapshot belongs to, so a snapshot is
/// only offered back on the screen for the same day.
struct SessionKey: Codable, Equatable {
    var week: Int
    var day: Int
    var makeup: Bool
}

/// A snapshot of a running session, persisted so it survives the app being
/// backgrounded, killed, or the timer screen being dismissed. One slot —
/// starting or finishing a session replaces or clears it.
///
/// Resume is deliberately *pause* semantics: it picks up exactly where the
/// runner left off, it does not fast-forward for wall-clock time elapsed while
/// the app was gone (that catch-up only applies to a session still in memory —
/// see ``SessionTimerModel/syncToWallClock()``).
struct InProgressSession: Codable, Equatable {
    /// A flattened phase, stored with the phase as a raw string so the blob
    /// never depends on a UIWorkouts type.
    struct Phase: Codable, Equatable {
        var phaseRaw: String
        var seconds: Int
    }

    var key: SessionKey
    var phases: [Phase]
    var segmentIndex: Int
    var secondsLeftInSegment: Int
    /// When the snapshot was written — used to expire a stale one.
    var savedAt: Date

    /// The flattened list rebuilt into a ``SessionPlan`` the timer can play.
    var sessionPlan: SessionPlan {
        SessionPlan(phases: phases.map {
            SessionPlan.Phase(phase: WKPhase(rawValue: $0.phaseRaw) ?? .run, seconds: $0.seconds)
        })
    }
}

/// The single-slot persistent store for an in-progress session, backed by
/// `UserDefaults` (a small JSON blob — no SwiftData migration surface).
enum SessionResumeStore {
    static let key = "inProgressSession"
    /// Snapshots older than this are ignored — a half-done session from days ago
    /// isn't something to drop the runner back into.
    static let maxAge: TimeInterval = 12 * 60 * 60

    static func save(_ session: InProgressSession, to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(now: Date = Date(),
                     from defaults: UserDefaults = .standard) -> InProgressSession? {
        guard let data = defaults.data(forKey: key),
              let session = try? JSONDecoder().decode(InProgressSession.self, from: data)
        else { return nil }
        guard now.timeIntervalSince(session.savedAt) <= maxAge else {
            clear(from: defaults)
            return nil
        }
        return session
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
