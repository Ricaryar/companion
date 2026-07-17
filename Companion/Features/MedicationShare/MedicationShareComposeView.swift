import SwiftUI
import PhotosUI

struct MedicationShareComposeView: View {
    let category: MedicationDiseaseCategory
    let subtype: String
    let therapyKind: MedicationTherapyKind
    let treatmentLine: String
    var onFinished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var store = MedicationShareStore.shared

    @State private var title = ""
    @State private var summary = ""
    @State private var bodyText = ""
    @State private var drugName = ""
    @State private var drugItems: [PhotosPickerItem] = []
    @State private var recordItems: [PhotosPickerItem] = []
    @State private var drugData: [Data] = []
    @State private var recordData: [Data] = []
    @State private var errorMessage: String?
    @State private var resultShare: MedicationShare?
    @State private var showResult = false

    var body: some View {
        Form {
            Section("分类") {
                Text("\(category.rawValue) > \(subtype) > \(therapyKind.rawValue) > \(treatmentLine)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if therapyKind.isCashIncentiveEligible {
                    Text("该类型审核通过后可获得 \(MedicationShareRules.baseCashYuan) 元现金（满 \(MedicationShareRules.withdrawMinYuan) 元可提现）。未达高质标准前将同时出现在社区与科普任务区。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.riskGreen)
                } else {
                    Text("常见药不纳入现金激励范围，审核后将自动投放至科普任务区并奖励健康豆")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("药品与内容") {
                TextField("药品名称", text: $drugName)
                TextField("标题（如：XX靶向药用药30天记录）", text: $title)
                TextField("摘要（列表展示用）", text: $summary, axis: .vertical)
                    .lineLimit(2...4)
                TextField("正文经历（副作用、复查、主观感受等）", text: $bodyText, axis: .vertical)
                    .lineLimit(6...14)
            }

            Section("药品图片（必填）") {
                PhotosPicker(selection: $drugItems, maxSelectionCount: 4, matching: .images) {
                    Label(drugData.isEmpty ? "选择药品图片" : "已选 \(drugData.count) 张", systemImage: "pills.circle")
                }
                .onChange(of: drugItems) { _, items in
                    Task { drugData = await loadAll(items) }
                }
            }

            Section("病历本照片（必填，证明真实性）") {
                PhotosPicker(selection: $recordItems, maxSelectionCount: 4, matching: .images) {
                    Label(recordData.isEmpty ? "上传病历本相关页" : "已选 \(recordData.count) 张", systemImage: "doc.text.image")
                }
                .onChange(of: recordItems) { _, items in
                    Task { recordData = await loadAll(items) }
                }
                Text("平台鼓励分享稀缺药物试用经验；图片仅用于审核真实性，请注意遮挡敏感个人信息。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("提交审核") { submit() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("填写分享")
        .navigationBarTitleDisplayMode(.inline)
        .alert("无法提交", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showResult) {
            if let resultShare {
                auditResultSheet(resultShare)
            }
        }
    }

    private func submit() {
        let draft = MedicationShareStore.Draft(
            title: title,
            summary: summary,
            body: bodyText,
            drugName: drugName,
            category: category,
            subtype: subtype,
            therapyKind: therapyKind,
            treatmentLine: treatmentLine,
            drugImageData: drugData,
            recordImageData: recordData
        )
        switch store.submit(draft) {
        case .success(let share):
            resultShare = share
            showResult = true
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func auditResultSheet(_ share: MedicationShare) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: share.isIncentiveEligible ? "checkmark.seal.fill" : "info.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(share.isIncentiveEligible ? AppTheme.riskGreen : AppTheme.brandTeal)
                Text(share.isIncentiveEligible ? "审核通过" : "已收到您的分享")
                    .font(.title3.bold())
                Text(share.auditMessage ?? "感谢分享")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if share.isIncentiveEligible {
                    Text("可在「真实用药」左上角查看现金余额，满 \(MedicationShareRules.withdrawMinYuan) 元提现。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("可在健康豆任务「科普阅读」中看到该类分享。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") {
                    showResult = false
                    onFinished?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brandTeal)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("审核结果")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
        .presentationDetents([.medium])
    }

    private func loadAll(_ items: [PhotosPickerItem]) async -> [Data] {
        var result: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                result.append(data)
            }
        }
        return result
    }
}
