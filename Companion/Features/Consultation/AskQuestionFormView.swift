import SwiftUI
import PhotosUI

struct AskQuestionFormView: View {
    @Binding var path: NavigationPath
    @State private var beans = HealthBeansStore.shared
    @State private var store = ConsultationStore.shared

    @State private var gender = "男"
    @State private var ageText = ""
    @State private var symptom: SymptomTag = .fever
    @State private var duration: SymptomDuration = .days1to3
    @State private var detail = ""
    @State private var medicationNote = ""
    @State private var selectedItems: [PhotosPickerItem] = []

    @State private var showConfirm = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var cost: Int { beans.consultationAskCost }
    private var detailCount: Int { detail.trimmingCharacters(in: .whitespacesAndNewlines).count }

    var body: some View {
        Form {
            Section("基本信息") {
                Picker("性别", selection: $gender) {
                    Text("男").tag("男")
                    Text("女").tag("女")
                }
                .pickerStyle(.segmented)
                TextField("年龄", text: $ageText)
                    .keyboardType(.numberPad)
            }

            Section("主要症状（必填）") {
                symptomGrid
            }

            Section("症状持续多久？（必填）") {
                Picker("时长", selection: $duration) {
                    ForEach(SymptomDuration.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                DetailTextEditor(text: $detail, minHeight: 120)
                Text("\(detailCount)/\(ConsultationRules.detailMax) 字（需 \(ConsultationRules.detailMin)–\(ConsultationRules.detailMax) 字）")
                    .font(.caption)
                    .foregroundStyle(detailCountValid ? .secondary : AppTheme.riskRed)
            } header: {
                Text("详细描述（必填）")
            }

            Section("是否已就诊/用药？（选填）") {
                TextField("如：已去社区医院，开了头孢", text: $medicationNote, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("上传图片（选填，最多3张）") {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: ConsultationRules.maxImages, matching: .images) {
                    Label(selectedItems.isEmpty ? "选择图片" : "已选 \(selectedItems.count) 张", systemImage: "photo.on.rectangle")
                }
            }

            Section {
                Text("所有信息仅用于医生诊断，平台将严格保密。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("我要提问")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                validateAndConfirm()
            } label: {
                Text("提交提问")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.brandTeal)
            .padding()
            .background(.ultraThinMaterial)
        }
        .alert("确认发起咨询", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认并提交") { submit() }
        } message: {
            Text(confirmMessage)
        }
        .alert("无法提交", isPresented: $showError) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var confirmMessage: String {
        let discountNote = beans.hasActiveMonthCard
            ? "（月卡用户享8折：\(ConsultationRules.monthCardAskCost)健康豆）"
            : ""
        return """
        本次咨询将消耗：\(cost)健康豆
        \(discountNote)

        医生回复后 6小时内 可免费追问1次
        第2次起追问：\(ConsultationRules.followUpCost)健康豆/次

        请确保您已如实填写病情描述。
        """
    }

    private var detailCountValid: Bool {
        (ConsultationRules.detailMin...ConsultationRules.detailMax).contains(detailCount)
    }

    private var symptomGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 70), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SymptomTag.askOptions) { tag in
                Button {
                    symptom = tag
                } label: {
                    Text(tag.rawValue)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(symptom == tag ? AppTheme.brandTeal : Color(.tertiarySystemFill))
                        .foregroundStyle(symptom == tag ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func validateAndConfirm() {
        guard let age = Int(ageText), (1...120).contains(age) else {
            errorMessage = "请填写有效年龄"
            showError = true
            return
        }
        guard detailCountValid else {
            errorMessage = "详细描述需在 \(ConsultationRules.detailMin)–\(ConsultationRules.detailMax) 字之间"
            showError = true
            return
        }
        showConfirm = true
    }

    private func submit() {
        guard let age = Int(ageText) else { return }
        let result = ConsultationStore.shared.submitConsultation(
            gender: gender,
            age: age,
            symptom: symptom,
            duration: duration,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            medicationNote: medicationNote.trimmingCharacters(in: .whitespacesAndNewlines),
            imageCount: selectedItems.count
        )
        switch result {
        case .success(let item):
            path.removeLast()
            path.append(QARoute.waiting(item.id))
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

private struct DetailTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("请尽量具体描述症状、诱因与变化…")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            TextEditor(text: $text)
                .frame(minHeight: minHeight)
        }
    }
}
