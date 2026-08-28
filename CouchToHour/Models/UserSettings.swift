import Foundation
import SwiftData
import UIWorkouts

/// Single-row app settings. Later modules add mode / schedule / weekday fields;
/// CTH-4 only needs the appearance choice.
@Model
final class UserSettings {
    /// Raw value of the selected ``WKThemeMode``. Stored as `String` so the
    /// persisted store never depends on a UIWorkouts type. Read/written through
    /// ``themeMode``.
    var themeModeRaw: String

    init(themeMode: WKThemeMode = .system) {
        self.themeModeRaw = themeMode.rawValue
    }

    /// Computed — the `@Model` macro leaves it out of the persisted schema.
    var themeMode: WKThemeMode {
        get { WKThemeMode(rawValue: themeModeRaw) ?? .system }
        set { themeModeRaw = newValue.rawValue }
    }
}

extension UserSettings {
    /// Returns the singleton settings row, creating and inserting it the first
    /// time it is asked for. Idempotent — safe to call from any screen.
    @discardableResult
    static func current(in context: ModelContext) -> UserSettings {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserSettings()
        context.insert(created)
        return created
    }
}
