import SwiftUI
import SwiftData

struct AddRegimenWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let repository = RegimenRepository.shared
    private let generator = ScheduleGenerator()

    @State private var step = 0
    @State private var selectedLine: TreatmentLineKind = .first
    @State private var useCustomName = false
    @State private var customRegimenName = ""
    @State private var selectedDrugCodes: Set<String> = []
    @State private var drugOralDrafts: [DrugOralScheduleDraft] = []
    @State private var startDate = Date.now
    @State private var includeTemplateInfusionAndVisits = false
    @State private var templateCycles = 6
    @State private var manualEvents: [ManualScheduleDraft] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: 3)
                    .padding()

                TabView(selection: $step) {
                    stepBasicInfo.tag(0)
                    stepScheduleConfig.tag(1)
                    stepConfirm.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                navigationButtons
            }
            .navigationTitle(CopyStrings.addRegimen)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var navigationButtons: some View {
        HStack {
            if step > 0 {
                Button("上一步") { step -= 1 }
            }
            Spacer()
            if step < 2 {
                Button("下一步") { step += 1 }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceedFromCurrentStep)
            } else {
                Button("保存") { saveRegimen() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding()
    }

    private var canProceedFromCurrentStep: Bool {
        switch step {
        case 0: !drugOralDrafts.isEmpty
        default: true
        }
    }

    private var canSave: Bool {
        !drugOralDrafts.isEmpty && (
            drugOralDrafts.contains(where: \.useCustomOral)
            || includeTemplateInfusionAndVisits
            || !manualEvents.isEmpty
        )
    }

    private var combinedDisplayName: String {
        drugOralDrafts.map(\.displayName).joined(separator: " + ")
    }

    private var combinedRegimenCode: String {
        drugOralDrafts.map(\.id).joined(separator: "|")
    }

    // MARK: - Step 0

    private var stepBasicInfo: some View {
        Form {
            Section {
                Text("可同时选择多种药物（如 TAS-102 + 呋喹替尼）。线数仅作记录。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("治疗线数（按医嘱）") {
                Picker("线数", selection: $selectedLine) {
                    ForEach(TreatmentLineKind.allCases, id: \.self) { line in
                        Text(line.displayName).tag(line)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("选择方案（可多选）") {
                Picker("来源", selection: $useCustomName) {
                    Text("从常见方案选择").tag(false)
                    Text("自己填写").tag(true)
                }
                .pickerStyle(.segmented)

                if useCustomName {
                    TextField("例如：TAS-102 + 呋喹替尼", text: $customRegimenName)
                    Button("加入方案列表") {
                        addCustomDrug()
                    }
                    .disabled(customRegimenName.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    selectableRegimenList
                }

                if !drugOralDrafts.isEmpty {
                    Text("已选 \(drugOralDrafts.count) 项：\(combinedDisplayName)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.brandTeal)
                }
            }

            Section("开始日期") {
                DatePicker("首个用药日 / 治疗开始", selection: $startDate, displayedComponents: .date)
            }

            Section {
                Text(CopyStrings.disclaimerRegimen)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectableRegimenList: some View {
        Group {
            let groups = repository.groupedAllSelectableRegimens()
            if groups.isEmpty {
                Text("暂无模板，请切换为「自己填写」。")
                    .foregroundStyle(.secondary)
            }
            ForEach(groups, id: \.category) { group in
                Section(group.category.displayName) {
                    ForEach(group.regimens) { def in
                        Toggle(isOn: drugToggleBinding(for: def)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(def.displayName)
                                if let summary = def.summary {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func drugToggleBinding(for def: RegimenDef) -> Binding<Bool> {
        Binding(
            get: { selectedDrugCodes.contains(def.code) },
            set: { isOn in
                if isOn {
                    selectedDrugCodes.insert(def.code)
                    if !drugOralDrafts.contains(where: { $0.id == def.code }) {
                        drugOralDrafts.append(DrugOralScheduleDraft(
                            code: def.code,
                            displayName: def.displayName,
                            regimen: def
                        ))
                    }
                } else {
                    selectedDrugCodes.remove(def.code)
                    drugOralDrafts.removeAll { $0.id == def.code }
                }
            }
        )
    }

    private func addCustomDrug() {
        let name = customRegimenName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let code = "CUSTOM-\(UUID().uuidString.prefix(8))"
        selectedDrugCodes.insert(code)
        drugOralDrafts.append(DrugOralScheduleDraft(code: code, displayName: name, regimen: nil))
        customRegimenName = ""
    }

    // MARK: - Step 1

    private var stepScheduleConfig: some View {
        Form {
            Section {
                Text("每一种药可分别设置剂量与「吃几天停几天」，互不影响。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach($drugOralDrafts) { $draft in
                Section(draft.displayName) {
                    Toggle("自定义口服日程", isOn: $draft.useCustomOral)

                    if draft.useCustomOral {
                        TextField("药物名称", text: $draft.config.drugName)
                        TextField("剂量（如 55mg）", text: $draft.config.doseText)
                        Stepper("连吃 \(draft.config.daysOn) 天", value: $draft.config.daysOn, in: 1...28)
                        Stepper("停 \(draft.config.daysOff) 天", value: $draft.config.daysOff, in: 0...28)
                        Stepper("重复 \(draft.config.repeatCycles) 个周期", value: $draft.config.repeatCycles, in: 1...24)

                        Toggle("早上服药", isOn: $draft.config.includeMorningDose)
                        if draft.config.includeMorningDose {
                            timePicker(hour: $draft.config.morningHour, minute: $draft.config.morningMinute, label: "早上时间")
                        }

                        Toggle("晚上服药", isOn: $draft.config.includeEveningDose)
                        if draft.config.includeEveningDose {
                            timePicker(hour: $draft.config.eveningHour, minute: $draft.config.eveningMinute, label: "晚上时间")
                        }

                        Picker("餐时", selection: $draft.config.mealTiming) {
                            ForEach(MealTiming.allCases, id: \.self) { timing in
                                Text(timing.displayName).tag(timing)
                            }
                        }
                    }
                }
            }

            if selectedDrugCodes.contains(where: { repository.regimen(for: $0) != nil }) {
                Section("输液 / 复诊（可选）") {
                    Toggle("同时生成模板中的输液、检验、复诊提醒", isOn: $includeTemplateInfusionAndVisits)
                    if includeTemplateInfusionAndVisits {
                        Stepper("生成 \(templateCycles) 个周期", value: $templateCycles, in: 1...12)
                    }
                }
            }

            Section("手动添加日程") {
                Text("输液日、验血、复诊等可按医生给的日期逐条添加。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach($manualEvents) { $draft in
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker("日期与时间", selection: $draft.date)
                        Picker("类型", selection: $draft.eventType) {
                            ForEach([ScheduleEventType.oral, .infusion, .lab, .imaging, .visit], id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        TextField("事项（如 输液、验血）", text: $draft.title)
                    }
                }
                .onDelete { manualEvents.remove(atOffsets: $0) }

                Button {
                    manualEvents.append(ManualScheduleDraft(
                        date: startDate,
                        eventType: .infusion,
                        title: ""
                    ))
                } label: {
                    Label("添加一条日程", systemImage: "plus.circle")
                }
            }
        }
    }

    private func timePicker(hour: Binding<Int>, minute: Binding<Int>, label: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker("时", selection: hour) {
                ForEach(0..<24, id: \.self) { h in Text("\(h) 时").tag(h) }
            }
            .labelsHidden()
            Picker("分", selection: minute) {
                ForEach([0, 15, 30, 45], id: \.self) { m in Text("\(m) 分").tag(m) }
            }
            .labelsHidden()
        }
    }

    // MARK: - Step 2

    private var stepConfirm: some View {
        Form {
            Section("方案") {
                LabeledContent("名称", value: combinedDisplayName)
                LabeledContent("线数", value: selectedLine.displayName)
                LabeledContent("开始", value: startDate.formatted(date: .long, time: .omitted))
                LabeledContent("药物数", value: "\(drugOralDrafts.count)")
            }

            Section("各药口服日程") {
                ForEach(drugOralDrafts) { draft in
                    if draft.useCustomOral {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.displayName).font(.subheadline.bold())
                            Text("连吃 \(draft.config.daysOn) 天，停 \(draft.config.daysOff) 天，共 \(draft.config.repeatCycles) 周期")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !draft.config.doseText.isEmpty {
                                Text("剂量：\(draft.config.doseText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("\(draft.displayName)：不生成口服提醒")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !manualEvents.isEmpty {
                Section("手动日程") {
                    Text("共 \(manualEvents.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }.count) 条")
                }
            }
        }
    }

    // MARK: - Save

    private func saveRegimen() {
        guard !drugOralDrafts.isEmpty else { return }

        let maxCycleDays = drugOralDrafts
            .filter(\.useCustomOral)
            .map { max(1, $0.config.daysOn + $0.config.daysOff) }
            .max() ?? 28

        let instance = RegimenInstance(
            regimenCode: combinedRegimenCode,
            displayName: combinedDisplayName,
            line: selectedLine,
            isMaintenance: selectedLine == .maintenance,
            startDate: Calendar.current.startOfDay(for: startDate),
            cycleDays: maxCycleDays
        )

        var allEvents: [ScheduleEvent] = []

        for draft in drugOralDrafts where draft.useCustomOral {
            let oralEvents = CustomOralScheduleBuilder.generateOralEvents(
                config: draft.config,
                startDate: startDate,
                regimen: instance
            )
            allEvents.append(contentsOf: oralEvents)
        }

        if includeTemplateInfusionAndVisits {
            for code in selectedDrugCodes {
                guard let def = repository.regimen(for: code) else { continue }
                let templateResult = generator.generate(
                    regimen: def,
                    line: selectedLine,
                    startDate: startDate,
                    cycles: templateCycles
                )
                let extras = templateResult.events.filter { $0.eventType != .oral }
                for event in extras {
                    event.regimen = instance
                    allEvents.append(event)
                }
            }
        }

        allEvents = generator.appendManualEvents(manualEvents, to: instance, startingEvents: allEvents)
        modelContext.insert(instance)
        for event in allEvents {
            modelContext.insert(event)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddRegimenWizardView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
