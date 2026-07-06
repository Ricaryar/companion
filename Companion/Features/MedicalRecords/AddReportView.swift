import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddReportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var attachedFileData: Data?
    @State private var attachedFileName: String?
    @State private var showFileImporter = false
    @State private var parseResult: ReportParseResult?
    @State private var labDrafts: [EditableLabDraft] = []
    @State private var title = ""
    @State private var reportType: ReportType = .lab
    @State private var reportDate = Date.now
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var hasAttachment: Bool {
        previewImage != nil || attachedFileData != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("选择文件") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(previewImage == nil ? "从相册选择图片" : "更换图片", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task { await loadPhoto(newItem) }
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Label(
                            attachedFileName ?? "从文件 App 选择（PDF、图片等）",
                            systemImage: "folder"
                        )
                    }

                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                            .reportImageLongPressSave(previewImage)
                    } else if let attachedFileName {
                        HStack {
                            Image(systemName: fileIconName)
                                .foregroundStyle(AppTheme.brandTeal)
                            Text(attachedFileName)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                    }

                    if isProcessing {
                        HStack {
                            ProgressView()
                            Text("正在识别…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let parseResult {
                    Section("OCR 预览") {
                        Text(parseResult.rawText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(12)
                        if !parseResult.ocrDebugSummary.isEmpty {
                            Text("识别引擎：\(parseResult.ocrDebugSummary)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("报告信息") {
                    TextField("标题", text: $title)
                    Picker("类型", selection: $reportType) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    DatePicker("日期", selection: $reportDate, displayedComponents: .date)
                }

                if !labDrafts.isEmpty {
                    Section {
                        Text("共识别 \(labDrafts.count) 项，请核对数值与参考区间后再保存。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Section("识别指标（可编辑）") {
                        ForEach($labDrafts) { $draft in
                            EditableLabRowView(draft: $draft)
                        }
                        .onDelete { labDrafts.remove(atOffsets: $0) }
                        Button("添加指标") {
                            labDrafts.append(EditableLabDraft(labType: "", value: "", unit: ""))
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.riskRed)
                    }
                }
            }
            .navigationTitle(CopyStrings.addReport)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveReport() }
                        .disabled(!hasAttachment || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .jpeg, .png, .heic, .image],
                allowsMultipleSelection: false
            ) { result in
                Task { await loadImportedFile(result) }
            }
        }
    }

    private var fileIconName: String {
        guard let name = attachedFileName?.lowercased() else { return "doc" }
        if name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".png") || name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") { return "photo" }
        return "doc"
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "无法加载图片"
                return
            }
            attachedFileData = nil
            attachedFileName = nil
            previewImage = image
            let result = try await ReportOCRService.parseReport(from: image)
            parseResult = result
            if title.isEmpty { title = result.suggestedTitle }
            reportType = result.reportType
            reportDate = result.reportDate
            labDrafts = result.labs.map { EditableLabDraft(from: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadImportedFile(_ result: Result<[URL], Error>) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            guard let url = try result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "无法读取所选文件"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent
            attachedFileName = name
            attachedFileData = data
            parseResult = nil
            labDrafts = []

            if let image = UIImage(data: data) {
                previewImage = image
                if reportType == .lab {
                    let result = try await ReportOCRService.parseReport(from: image)
                    parseResult = result
                    if title.isEmpty { title = result.suggestedTitle }
                    reportType = result.reportType
                    reportDate = result.reportDate
                    labDrafts = result.labs.map { EditableLabDraft(from: $0) }
                } else if title.isEmpty {
                    title = (name as NSString).deletingPathExtension
                }
            } else {
                previewImage = nil
                if title.isEmpty {
                    title = (name as NSString).deletingPathExtension
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveReport() {
        guard hasAttachment else { return }
        let editedLabs = labDrafts.filter(\.isSelected).compactMap { $0.toExtracted() }
        let finalTitle = title.trimmingCharacters(in: .whitespaces)

        do {
            _ = try ReportImportService.saveManual(
                context: modelContext,
                title: finalTitle,
                reportType: reportType,
                reportDate: reportDate,
                image: previewImage,
                fileData: previewImage == nil ? attachedFileData : nil,
                fileName: attachedFileName,
                parse: parseResult,
                labs: editedLabs.isEmpty ? nil : editedLabs
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddReportView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
