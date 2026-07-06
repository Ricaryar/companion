import SwiftUI
import SwiftData
import UIKit

/// 全部就医文件：检验、发票、出院小结等，支持按类型筛选与导出
struct DocumentsLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MedicalReport.reportDate, order: .reverse) private var reports: [MedicalReport]

    let navigationTitle: String
    var includedTypes: Set<ReportType>?
    var showMedicalShortcuts: Bool = false

    @State private var selectedType: ReportType?
    @State private var showAddReport = false

    private var filteredReports: [MedicalReport] {
        var list = reports
        if let includedTypes {
            list = list.filter { includedTypes.contains($0.reportType) }
        }
        if let selectedType {
            list = list.filter { $0.reportType == selectedType }
        }
        return list
    }

    var body: some View {
        Group {
            if filteredReports.isEmpty && !showMedicalShortcuts {
                ContentUnavailableView(
                    "暂无文件",
                    systemImage: "folder",
                    description: Text("可上传图片或 PDF 等文件，保存在本机，长按图片可保存到相册。")
                )
            } else {
                List {
                    if showMedicalShortcuts {
                        Section("就医准备") {
                            NavigationLink {
                                DoctorPrepView()
                            } label: {
                                Label("与医生沟通", systemImage: "person.2.wave.2")
                            }
                            NavigationLink {
                                ExportSummaryView()
                            } label: {
                                Label("导出检验摘要", systemImage: "doc.richtext")
                            }
                        }
                    }

                    if includedTypes == nil && showMedicalShortcuts {
                        Section {
                            Text("支持图片与 PDF 等格式。点进详情可查看附件；图片长按可保存到相册。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if includedTypes == nil {
                        Section {
                            Text("所有上传的报告与文件保存在本机。图片长按可保存到相册。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if filteredReports.isEmpty {
                        Section {
                            Text("暂无文件，点右上角 + 添加。")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("我的文件") {
                            ForEach(filteredReports) { report in
                                NavigationLink {
                                    ReportDetailView(report: report)
                                } label: {
                                    reportRow(report)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteReport(report)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        ReportFileActions.shareReport(report)
                                    } label: {
                                        Label("分享/保存", systemImage: "square.and.arrow.up")
                                    }
                                    if let path = report.filePath,
                                       let image = ReportFileStore.loadImage(storedPath: path) {
                                        Button {
                                            Task {
                                                _ = await ReportFileActions.saveImageToPhotos(image)
                                            }
                                        } label: {
                                            Label("保存图片到相册", systemImage: "square.and.arrow.down")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddReport = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if includedTypes == nil {
                typeFilterBar
            }
        }
        .sheet(isPresented: $showAddReport) {
            AddReportView()
        }
    }

    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "全部", type: nil)
                ForEach(ReportType.allCases, id: \.self) { type in
                    filterChip(title: type.displayName, type: type)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func filterChip(title: String, type: ReportType?) -> some View {
        let selected = selectedType == type
        return Button {
            selectedType = type
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? AppTheme.brandTeal : AppTheme.cardBackground)
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func reportRow(_ report: MedicalReport) -> some View {
        HStack(spacing: 12) {
            reportThumbnail(report)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(report.title)
                        .font(.headline)
                        .lineLimit(1)
                    if report.isPrivacyLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    Text(report.reportType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.brandIndigo.opacity(0.12))
                        .clipShape(Capsule())
                    Text(report.reportDate, format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if report.reportType == .lab, !report.labResults.isEmpty {
                    Text("\(report.labResults.count) 项指标")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let path = report.filePath {
                    Text(ReportFileStore.isImagePath(path) ? "长按图片可保存" : ReportFileStore.displayFileName(storedPath: path))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func reportThumbnail(_ report: MedicalReport) -> some View {
        if let path = report.filePath, let thumb = ReportFileStore.loadImage(storedPath: path) {
            Image(uiImage: thumb)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .reportImageLongPressSave(thumb)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.brandTeal.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: iconForType(report.reportType))
                        .foregroundStyle(AppTheme.brandTeal)
                }
        }
    }

    private func iconForType(_ type: ReportType) -> String {
        switch type {
        case .lab: "flask"
        case .invoice: "doc.text"
        case .imaging: "photo"
        case .pathology, .genetic: "cross.case"
        case .discharge, .order: "doc.plaintext"
        }
    }

    private func deleteReport(_ report: MedicalReport) {
        ReportDeletionService.delete(report, in: modelContext)
    }
}

#Preview {
    NavigationStack {
        DocumentsLibraryView(navigationTitle: "文件", showMedicalShortcuts: true)
    }
    .modelContainer(CompanionModelContainer.make(inMemory: true))
}
