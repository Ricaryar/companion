import Foundation
import SwiftData

enum ScheduleEventActions {
    static func markDone(_ event: ScheduleEvent, context: ModelContext) {
        event.status = .done
        event.completedAt = .now
        try? context.save()
    }

    static func markPending(_ event: ScheduleEvent, context: ModelContext) {
        event.status = .pending
        event.completedAt = nil
        event.deferredTo = nil
        try? context.save()
    }

    static func toggleCompletion(_ event: ScheduleEvent, context: ModelContext) {
        if event.status == .done {
            markPending(event, context: context)
        } else {
            markDone(event, context: context)
        }
    }

    static func markDone(_ events: [ScheduleEvent], context: ModelContext) {
        let now = Date.now
        for event in events where event.status == .pending || event.status == .deferred {
            event.status = .done
            event.completedAt = now
        }
        try? context.save()
    }
}
