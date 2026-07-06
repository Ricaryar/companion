import SwiftUI
import SwiftData

struct ReportDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var report: MedicalReport

    @State private var isReOCRProcessing = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let path = report.filePath {
                if let image = ReportFileStore.loadImage(storedPath: path) {
                    Section {
                        Text("长按图片可保存到相册")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Section("报告图片") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .reportImageLongPressSave(image)
                    }
                } else if ReportFileStore.fileExists(storedPath: path) {
                    Section("附件") {
                        LabeledContent("文件名", value: ReportFileStore.displayFileName(storedPath: path))
                        Text("可通过下方「分享/保存文件」导出到文件 App 或其他应用。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("基本信息") {
                TextField("标题", text: $report.title)
                Picker("类型", selection: Binding(
                    get: { report.reportType },
                    set: { report.reportType = $0 }
                )) {
                    ForEach(ReportType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                DatePicker("日期", selection: $report.reportDate, displayedComponents: .date)
            }

            Section {
                if let path = report.filePath, ReportFileStore.isImagePath(path) {
                    Button {
                        Task { await reRunOCR() }
                    } label: {
                        HStack {
                            Label("重新识别", systemImage: "text.viewfinder")
                            if isReOCRProcessing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isReOCRProcessing || report.reportType != .lab)
                }

                Button {
                    prepareShare()
                    showShareSheet = true
                } label: {
                    Label("分享/保存文件", systemImage: "square.and.arrow.up")
                }
                .disabled(report.filePath == nil)

                Button("删除报告", role: .destructive) {
                    ReportDeletionService.delete(report, in: modelContext)
                }
            }

            if let ocr = report.ocrText, !ocr.isEmpty {
                Section("OCR 原文") {
                    Text(ocr)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if !report.labResults.isEmpty {
                Section("检验指标 (\(report.labResults.count))") {
                    ForEach(report.labResults.sorted(by: { $0.displayLabel < $1.displayLabel })) { lab in
                        HStack {
                            Text(lab.displayLabel)
                            Spacer()
                            Text(String(format: "%.2f", lab.value))
                                .fontWeight(.medium)
                            Text(lab.unit)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            if lab.isOutOfRange {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(AppTheme.riskRed)
                                    .font(.caption)
                            }
                        }
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
        .navigationTitle(report.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    @MainActor
    private func reRunOCR() async {
        guard let path = report.filePath,
              ReportFileStore.isImagePath(path),
              let image = ReportFileStore.loadImage(storedPath: path) else { return }
        isReOCRProcessing = true
        errorMessage = nil
        defer { isReOCRProcessing = false }

        do {
            _ = try await ReportImportService.reparseExisting(
                report: report,
                image: image,
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareShare() {
        guard let path = report.filePath else { return }
        if let image = ReportFileStore.loadImage(storedPath: path) {
            shareItems = [image]
            return
        }
        let url = ReportFileStore.fileURL(forStoredPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            shareItems = [url]
            return
        }
        var lines = ["【\(report.title)】"]
        lines.append("类型：\(report.reportType.displayName)")
        lines.append("日期：\(report.reportDate.formatted(date: .long, time: .omitted))")
        shareItems = [lines.joined(separator: "\n")]
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ReportDetailView(report: MedicalReport(reportType: .lab, title: "血常规"))
    }
    .modelContainer(CompanionModelContainer.make(inMemory: true))
}
