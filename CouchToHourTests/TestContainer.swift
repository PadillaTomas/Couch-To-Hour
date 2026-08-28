import SwiftData
import XCTest
@testable import CouchToHour

@MainActor
extension XCTestCase {
    /// A fresh store on the real app schema with the 6-week plan seeded.
    ///
    /// - On-disk temp file, not in-memory: SwiftData's in-memory configuration
    ///   mishandles part of this model graph.
    /// - The teardown block strongly captures `container`, which keeps the store
    ///   open for the whole test even when the caller only holds `.mainContext`
    ///   (`ModelContext` does **not** retain its `ModelContainer`).
    func seededContainer() throws -> ModelContainer {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cth-test-\(UUID().uuidString).store")

        let container = try ModelContainer(
            for: CouchToHourSchema.schema,
            configurations: ModelConfiguration(url: url)
        )
        PlanSeed.seed(into: container.mainContext)
        try container.mainContext.save()

        addTeardownBlock {
            _ = container   // hold the container until the test finishes
            let fm = FileManager.default
            try? fm.removeItem(at: url)
            try? fm.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
            try? fm.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        }
        return container
    }
}
