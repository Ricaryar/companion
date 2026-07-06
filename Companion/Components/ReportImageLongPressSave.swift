import SwiftUI
import PhotosUI

/// 报告图片：长按/上下文菜单保存到相册
struct ReportImageLongPressSaveModifier: ViewModifier {
    let image: UIImage
    @State private var saveMessage: String?
    @State private var showSaveAlert = false

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    Task { await save() }
                } label: {
                    Label("保存到相册", systemImage: "square.and.arrow.down")
                }
                Button {
                    ReportFileActions.shareItems([image])
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                Task { await save() }
            }
            .alert("保存照片", isPresented: $showSaveAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(saveMessage ?? "")
            }
    }

    @MainActor
    private func save() async {
        if let error = await ReportFileActions.saveImageToPhotos(image) {
            saveMessage = error
        } else {
            saveMessage = "已保存到相册"
        }
        showSaveAlert = true
    }
}

extension View {
    func reportImageLongPressSave(_ image: UIImage?) -> some View {
        modifier(OptionalReportImageSaveModifier(image: image))
    }
}

private struct OptionalReportImageSaveModifier: ViewModifier {
    let image: UIImage?

    func body(content: Content) -> some View {
        if let image {
            content.modifier(ReportImageLongPressSaveModifier(image: image))
        } else {
            content
        }
    }
}
