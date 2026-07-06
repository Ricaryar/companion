import Photos
import UIKit

enum ReportFileActions {
    @MainActor
    static func saveImageToPhotos(_ image: UIImage) async -> String? {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            return "请在系统设置中允许伴行保存照片到相册"
        }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: error?.localizedDescription ?? "保存失败")
                }
            }
        }
    }

    @MainActor
    static func shareItems(_ items: [Any]) {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        topViewController()?.present(controller, animated: true)
    }

    @MainActor
    static func shareReport(_ report: MedicalReport) {
        guard let path = report.filePath else { return }
        if let image = ReportFileStore.loadImage(storedPath: path) {
            shareItems([image])
            return
        }
        let url = ReportFileStore.fileURL(forStoredPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        shareItems([url])
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
