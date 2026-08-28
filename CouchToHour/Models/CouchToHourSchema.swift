import SwiftData

/// The app's SwiftData schema. A stub for now — CTH-4 only persists
/// `UserSettings`. The plan/session `@Model` graph lands in CTH-5. No
/// versioned schema or migration plan until there is something to migrate.
enum CouchToHourSchema {
    static let models: [any PersistentModel.Type] = [
        UserSettings.self
    ]

    static var schema: Schema { Schema(models) }
}
