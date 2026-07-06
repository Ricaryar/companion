import SwiftData

enum CompanionModelContainer {
    static let schema = Schema([
        TreatmentProfile.self,
        RegimenInstance.self,
        ScheduleEvent.self,
        SymptomLog.self,
        OstomyLog.self,
        MedicalReport.self,
        LabResult.self,
    ])

    static func make(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("无法创建数据库: \(error)")
        }
    }
}
