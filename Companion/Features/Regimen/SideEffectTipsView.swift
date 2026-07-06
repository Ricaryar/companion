import SwiftUI

struct SideEffectTipsView: View {
    let regimenCodes: [String]
    let title: String

    private let repository = SideEffectRepository.shared

    private var drugProfiles: [DrugSideEffectProfile] {
        repository.drugProfiles(forRegimenCodes: regimenCodes)
    }

    var body: some View {
        List {
            if drugProfiles.isEmpty {
                ContentUnavailableView(
                    "暂无副作用信息",
                    systemImage: "pills",
                    description: Text("当前方案暂未收录副作用提示，请以医生医嘱和药品说明书为准。")
                )
            } else {
                introSection

                ForEach(drugProfiles) { drug in
                    Section(drug.displayName) {
                        ForEach(drug.sideEffects) { entry in
                            SideEffectEntryRow(entry: entry)
                        }
                    }
                }
            }

            disclaimerSection
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introSection: some View {
        Section {
            Text("以下是当前方案涉及药物的常见副作用与应对参考。出现不适时请先对照观察，必要时及时联系医生。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var disclaimerSection: some View {
        Section {
            if let note = repository.catalog?.guidelineNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let reviewed = repository.catalog?.reviewedAt {
                Text("内容审阅日期：\(reviewed)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(CopyStrings.disclaimerSideEffects)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SideEffectEntryRow: View {
    let entry: SideEffectEntry
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                bulletBlock(title: "留意信号", icon: "eye", color: AppTheme.brandTeal, items: entry.watchFor)
                bulletBlock(title: "可尝试", icon: "hand.raised", color: AppTheme.riskGreen, items: entry.selfCare)
                bulletBlock(title: "联系医生", icon: "phone.fill", color: AppTheme.riskRed, items: entry.callDoctor)
                if !entry.sources.isEmpty {
                    Text("参考：\(entry.sources.joined(separator: "、"))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        } label: {
            HStack(spacing: 8) {
                if SideEffectSymptomKey(rawValue: entry.symptomKey)?.isTrackedInCheckIn == true {
                    Image(systemName: "checklist")
                        .font(.caption)
                        .foregroundStyle(AppTheme.brandIndigo)
                }
                Text(entry.label)
                    .font(.subheadline)
            }
        }
    }

    private func bulletBlock(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                Text("· \(item)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension SideEffectTipsView {
    init(regimen: RegimenInstance) {
        self.regimenCodes = [regimen.regimenCode]
        self.title = "副作用提示"
    }

    init(activeRegimens: [RegimenInstance]) {
        self.regimenCodes = activeRegimens.map(\.regimenCode)
        self.title = "副作用提示"
    }
}

#Preview {
    NavigationStack {
        SideEffectTipsView(regimenCodes: ["CAPOX"], title: "副作用提示")
    }
}
