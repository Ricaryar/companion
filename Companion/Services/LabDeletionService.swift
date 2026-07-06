import Foundation
import SwiftData

enum LabDeletionService {
    @MainActor
    static func delete(_ lab: LabResult, in context: ModelContext) {
        if let report = lab.sourceReport {
            report.labResults.removeAll { $0.persistentModelID == lab.persistentModelID }
        }
        context.delete(lab)
        try? context.save()
    }

    @MainActor
    static func deleteAll(forSourceReportKey key: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<LabResult>()
        let allLabs = (try? context.fetch(descriptor)) ?? []
        for lab in allLabs where lab.sourceReportKey == key {
            context.delete(lab)
        }
        try? context.save()
    }

    @MainActor
    static func deleteAll(in context: ModelContext) {
        let labs = (try? context.fetch(FetchDescriptor<LabResult>())) ?? []
        for lab in labs {
            context.delete(lab)
        }
        try? context.save()
    }
}
