import SwiftData

/// The app's SwiftData schema. CTH-4 persisted only `UserSettings`; CTH-5 adds
/// the plan `@Model` graph and completion history. Still no versioned schema or
/// migration plan — there is no shipped store to migrate, and every new field
/// on `UserSettings` is defaulted so lightweight migration covers the CTH-4 row.
enum CouchToHourSchema {
    static let models: [any PersistentModel.Type] = [
        UserSettings.self,
        WorkoutPlan.self,
        WorkoutWeek.self,
        WorkoutDay.self,
        Interval.self,
        CompletionRecord.self,
    ]

    static var schema: Schema { Schema(models) }
}
