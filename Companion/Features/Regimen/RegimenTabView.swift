import SwiftUI
import SwiftData

struct RegimenTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RegimenInstance.createdAt, order: .reverse) private var regimens: [RegimenInstance]
    @State private var showAddWizard = false

    private var activeRegimens: [RegimenInstance] { regimens.filter(\.isActive) }
    private var inactiveRegimens: [RegimenInstance] { regimens.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            List {
                if regimens.isEmpty {
                    ContentUnavailableView(
                        CopyStrings.emptyRegimen,
                        systemImage: "pills",
                        description: Text("按医生医嘱添加方案，自行设置用药日期与剂量。")
                    )
                }

                if !activeRegimens.isEmpty {
                    Section("进行中") {
                        ForEach(activeRegimens) { regimen in
                            regimenRow(regimen)
                        }
                        .onDelete { deleteRegimens(from: activeRegimens, at: $0) }
                    }
                }

                if !inactiveRegimens.isEmpty {
                    Section("已结束") {
                        ForEach(inactiveRegimens) { regimen in
                            regimenRow(regimen)
                        }
                        .onDelete { deleteRegimens(from: inactiveRegimens, at: $0) }
                    }
                }
            }
            .navigationTitle("我的方案")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddWizard = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddWizard) {
                AddRegimenWizardView()
            }
        }
    }

    private func regimenRow(_ regimen: RegimenInstance) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(regimen.displayName)
                    .font(.headline)
                Spacer()
                Text(regimen.line.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.brandTeal.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text("第 \(regimen.currentCycleIndex) 周期 · \(regimen.cycleDays) 天/周期")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("开始：\(regimen.startDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if regimen.isActive {
                HStack {
                    NavigationLink {
                        SideEffectTipsView(regimen: regimen)
                    } label: {
                        Label("副作用提示", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button("结束方案") {
                        RegimenLifecycle.endRegimen(regimen, context: modelContext)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteRegimens(from list: [RegimenInstance], at offsets: IndexSet) {
        for index in offsets {
            RegimenLifecycle.deleteRegimen(list[index], context: modelContext)
        }
    }
}

#Preview {
    RegimenTabView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
