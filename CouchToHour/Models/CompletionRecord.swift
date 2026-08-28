import Foundation
import SwiftData

/// One completed session. Written manually ("mark Done") or automatically on
/// timer completion; the 1–10 effort rating is filled in afterwards by the
/// post-workout screen (CTH-7), so ``feltRating`` is optional until then.
@Model
final class CompletionRecord {
    var date: Date
    /// `"W3D2"`-style coordinate of the `WorkoutDay` this completes — see
    /// ``WorkoutDay/completionKey``. Not a `PersistentIdentifier`, so history
    /// survives a store rebuild / reseed.
    var workoutDayKey: String
    var durationSeconds: Int
    /// Effort rating 1…10. `nil` until the post-workout screen records it.
    var feltRating: Int?
    /// Reserved for MVP+ (local file reference). Unused in Step 1.
    var photoPath: String?

    init(date: Date,
         workoutDayKey: String,
         durationSeconds: Int,
         feltRating: Int? = nil,
         photoPath: String? = nil) {
        self.date = date
        self.workoutDayKey = workoutDayKey
        self.durationSeconds = durationSeconds
        self.feltRating = feltRating
        self.photoPath = photoPath
    }

    /// The `(week, day)` this completes, parsed back from ``workoutDayKey``
    /// (`"W2D1"`).
    var workoutCoordinate: (week: Int, day: Int)? {
        let parts = workoutDayKey.dropFirst().split(separator: "D")
        guard parts.count == 2, let week = Int(parts[0]), let day = Int(parts[1]) else { return nil }
        return (week, day)
    }
}
