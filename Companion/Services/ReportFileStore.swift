import Foundation
import UIKit

enum ReportFileStore {
    static var reportsDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Reports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func saveImage(_ image: UIImage, preferredName: String = UUID().uuidString) throws -> String {
        let fileName = "\(preferredName).jpg"
        let url = fileURL(forStoredPath: fileName)
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            throw ReportStoreError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
        return fileName
    }

    static func saveFile(data: Data, originalName: String) throws -> String {
        let ext = sanitizedExtension(from: originalName)
        let fileName = "\(UUID().uuidString).\(ext)"
        let url = fileURL(forStoredPath: fileName)
        try data.write(to: url, options: .atomic)
        return fileName
    }

    static func fileURL(forStoredPath storedPath: String) -> URL {
        if storedPath.hasPrefix("/") {
            return URL(fileURLWithPath: storedPath)
        }
        let name = (storedPath as NSString).lastPathComponent
        return reportsDirectory.appendingPathComponent(name)
    }

    static func fileExists(storedPath: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(forStoredPath: storedPath).path)
    }

    static func isImagePath(_ storedPath: String) -> Bool {
        let ext = fileURL(forStoredPath: storedPath).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "webp", "gif"].contains(ext)
    }

    static func displayFileName(storedPath: String) -> String {
        fileURL(forStoredPath: storedPath).lastPathComponent
    }

    static func loadImage(storedPath: String) -> UIImage? {
        guard isImagePath(storedPath) else { return nil }
        let url = fileURL(forStoredPath: storedPath)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            return nil
        }
        return image.normalizedUpOrientation()
    }

    static func deleteFile(storedPath: String) {
        let url = fileURL(forStoredPath: storedPath)
        try? FileManager.default.removeItem(at: url)
    }

    private static func sanitizedExtension(from name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        if ext.isEmpty { return "dat" }
        let allowed = ["jpg", "jpeg", "png", "heic", "webp", "gif", "pdf", "doc", "docx", "dat"]
        return allowed.contains(ext) ? ext : "dat"
    }
}

enum ReportStoreError: Error {
    case encodingFailed
    case fileNotFound
}
