import SwiftData
@testable import CouchToHour

/// A fresh in-memory store on the real app schema, for engine tests.
@MainActor
enum TestContainer {
    static func make() throws -> ModelContainer {
        try ModelContainer(
            for: CouchToHourSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// In-memory container with the 6-week plan already seeded.
    static func seeded() throws -> ModelContainer {
        let container = try make()
        PlanSeed.seed(into: container.mainContext)
        try container.mainContext.save()
        return container
    }
}
