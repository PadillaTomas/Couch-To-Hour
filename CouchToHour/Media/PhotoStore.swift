import UIKit

enum PhotoStoreError: Error { case notAnImage, encodeFailed }

/// Local storage for post-workout photos. Images are written as downscaled
/// JPEGs into `Application Support/session-photos/`; `CompletionRecord.photoPath`
/// holds only the file name, resolved against that directory at read time — so a
/// reinstall that moves the app container doesn't strand every reference.
enum PhotoStore {
    /// Longest edge a stored photo is scaled to. A workout snapshot doesn't need
    /// full resolution and the file rides along in the device backup.
    static let maxEdge: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.8

    static var directory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("session-photos", isDirectory: true)
    }

    static func url(for fileName: String, in directory: URL = PhotoStore.directory) -> URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Writes `data` (any `UIImage`-decodable format) as a downscaled JPEG and
    /// returns the file name to store in `photoPath`.
    @discardableResult
    static func save(_ data: Data, in directory: URL = PhotoStore.directory) throws -> String {
        guard let image = UIImage(data: data) else { throw PhotoStoreError.notAnImage }
        return try save(image, in: directory)
    }

    /// Writes `image` as a downscaled JPEG and returns the file name.
    @discardableResult
    static func save(_ image: UIImage, in directory: URL = PhotoStore.directory) throws -> String {
        guard let jpeg = downscaled(image).jpegData(compressionQuality: jpegQuality) else {
            throw PhotoStoreError.encodeFailed
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).jpg"
        try jpeg.write(to: url(for: fileName, in: directory), options: .atomic)
        return fileName
    }

    static func load(_ fileName: String, in directory: URL = PhotoStore.directory) -> UIImage? {
        UIImage(contentsOfFile: url(for: fileName, in: directory).path)
    }

    static func delete(_ fileName: String, in directory: URL = PhotoStore.directory) {
        try? FileManager.default.removeItem(at: url(for: fileName, in: directory))
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let size = CGSize(width: (image.size.width * scale).rounded(),
                          height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
