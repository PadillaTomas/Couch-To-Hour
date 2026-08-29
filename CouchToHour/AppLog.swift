import OSLog
import SwiftData

/// App-wide logging. `Console.app` / Xcode's console filter on subsystem
/// `com.padillatomas.couchtohour`.
enum AppLog {
    static let data = Logger(subsystem: "com.padillatomas.couchtohour", category: "data")
}

extension ModelContext {
    /// Save, logging any failure instead of silently swallowing it with `try?`.
    /// A failed write here means a lost session / setting — worth seeing.
    func saveChanges(_ what: StaticString = "changes") {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            AppLog.data.error("save failed (\(what, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        }
    }
}
