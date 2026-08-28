import Foundation
import SwiftData
import SwiftUI

@main
struct CouchToHourApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            // The simulator's app container can ship without Application Support;
            // SwiftData's default store URL lives there. Create it up front.
            let appSupport = URL.applicationSupportDirectory
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

            let container = try ModelContainer(for: CouchToHourSchema.schema)
            // First-launch: make sure the single settings row exists so every
            // screen can bind to it synchronously, and seed the fixed 6-week
            // plan. Both are idempotent — safe on every launch.
            UserSettings.current(in: container.mainContext)
            PlanSeed.seed(into: container.mainContext)
            try? container.mainContext.save()
            modelContainer = container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
