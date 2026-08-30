import UIKit
import XCTest
@testable import CouchToHour

final class PhotoStoreTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("photostore-\(UUID().uuidString)", isDirectory: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A PNG that is exactly `size` *pixels* (scale 1), so the round-tripped
    /// `UIImage.size` is comparable to what we asked for.
    private func imageData(_ size: CGSize) -> Data {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }.pngData()!
    }

    func testSaveThenLoadRoundTrips() throws {
        let name = try PhotoStore.save(imageData(CGSize(width: 400, height: 300)), in: dir)
        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: PhotoStore.url(for: name, in: dir).path))
        XCTAssertNotNil(PhotoStore.load(name, in: dir))
    }

    func testOversizeImageIsDownscaledToTheMaxEdge() throws {
        let name = try PhotoStore.save(imageData(CGSize(width: 4000, height: 2000)), in: dir)
        let loaded = try XCTUnwrap(PhotoStore.load(name, in: dir))
        XCTAssertEqual(max(loaded.size.width, loaded.size.height), PhotoStore.maxEdge, accuracy: 1)
    }

    func testSmallImageIsLeftAtItsSize() throws {
        let name = try PhotoStore.save(imageData(CGSize(width: 200, height: 120)), in: dir)
        let loaded = try XCTUnwrap(PhotoStore.load(name, in: dir))
        XCTAssertEqual(loaded.size.width, 200, accuracy: 1)
        XCTAssertEqual(loaded.size.height, 120, accuracy: 1)
    }

    func testDeleteRemovesTheFile() throws {
        let name = try PhotoStore.save(imageData(CGSize(width: 100, height: 100)), in: dir)
        PhotoStore.delete(name, in: dir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: PhotoStore.url(for: name, in: dir).path))
        XCTAssertNil(PhotoStore.load(name, in: dir))
    }

    func testNonImageDataThrows() {
        XCTAssertThrowsError(try PhotoStore.save(Data("not an image".utf8), in: dir))
    }
}
