import SwiftUI

/// 发布前必须完成的分级分类：疾病大类 > 子类 > 用药类型 > 治疗线
struct MedicationShareCategoryPickerView: View {
    var onFinished: (() -> Void)? = nil

    @State private var category: MedicationDiseaseCategory?
    @State private var subtype: String = ""
    @State private var therapy: MedicationTherapyKind?
    @State private var treatmentLine: String = ""
    @State private var goCompose = false

    private var canContinue: Bool {
        category != nil && !subtype.isEmpty && therapy != nil && !treatmentLine.isEmpty
    }

    private var pathPreview: String {
        let c = category?.rawValue ?? "…"
        let s = subtype.isEmpty ? "…" : subtype
        let t = therapy?.rawValue ?? "…"
        let l = treatmentLine.isEmpty ? "…" : treatmentLine
        return "\(c) > \(s) > \(t) > \(l)"
    }

    var body: some View {
        Form {
            Section {
                Text("请依次完成分类选择，才能进入内容填写。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(pathPreview)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.brandTeal)
            }

            Section("① 疾病大类") {
                ForEach(MedicationDiseaseCategory.allCases) { item in
                    Button {
                        category = item
                        subtype = ""
                        therapy = nil
                        treatmentLine = ""
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.rawValue)
                                    .foregroundStyle(.primary)
                                Text(item.audienceHint)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if category == item {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.brandTeal)
                            }
                        }
                    }
                }
            }

            if let category {
                Section("② 疾病子类") {
                    ForEach(category.subtypes, id: \.self) { item in
                        Button {
                            subtype = item
                            therapy = nil
                            treatmentLine = ""
                        } label: {
                            HStack {
                                Text(item).foregroundStyle(.primary)
                                Spacer()
                                if subtype == item {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.brandTeal)
                                }
                            }
                        }
                    }
                }
            }

            if !subtype.isEmpty {
                Section("③ 用药类型") {
                    ForEach(MedicationTherapyKind.allCases) { item in
                        Button {
                            therapy = item
                            treatmentLine = ""
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.rawValue).foregroundStyle(.primary)
                                    Text(item.isCashIncentiveEligible ? "可参与现金激励" : "不纳入现金激励，可进科普区")
                                        .font(.caption2)
                                        .foregroundStyle(item.isCashIncentiveEligible ? AppTheme.riskGreen : .secondary)
                                }
                                Spacer()
                                if therapy == item {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.brandTeal)
                                }
                            }
                        }
                    }
                }
            }

            if let therapy {
                Section("④ 治疗线 / 使用场景") {
                    ForEach(therapy.treatmentLines, id: \.self) { item in
                        Button {
                            treatmentLine = item
                        } label: {
                            HStack {
                                Text(item).foregroundStyle(.primary)
                                Spacer()
                                if treatmentLine == item {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.brandTeal)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button("进入内容填写") {
                    goCompose = true
                }
                .disabled(!canContinue)
                .frame(maxWidth: .infinity)
            } footer: {
                Text("常见药不纳入现金激励范围；稀缺药物试用经验审核通过后奖金更高。")
                    .font(.caption2)
            }
        }
        .navigationTitle("选择分类")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goCompose) {
            if let category, let therapy {
                MedicationShareComposeView(
                    category: category,
                    subtype: subtype,
                    therapyKind: therapy,
                    treatmentLine: treatmentLine,
                    onFinished: onFinished
                )
            } else {
                EmptyView()
            }
        }
    }
}
