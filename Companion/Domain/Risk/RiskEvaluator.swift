import Foundation

struct RiskEvaluator {
    let rules: SymptomRiskRules

    init(rules: SymptomRiskRules? = RiskRulesRepository.shared.catalog?.symptomRules) {
        self.rules = rules ?? SymptomRiskRules(
            feverRedC: 38.0,
            feverYellowLowC: 37.5,
            feverYellowHighC: 37.9,
            painRed: 7,
            painYellow: 4,
            diarrheaRedPerDay: 6,
            diarrheaYellowLow: 3,
            diarrheaYellowHigh: 5,
            vomitRedPerDay: 3,
            cipnRed: 8,
            cipnYellowLow: 5,
            cipnYellowHigh: 7
        )
    }

    func evaluate(_ log: SymptomLog) -> RiskLevel {
        var level: RiskLevel = .green

        if let fever = log.fever {
            if fever >= rules.feverRedC {
                level = maxLevel(level, .red)
            } else if fever >= rules.feverYellowLowC && fever <= rules.feverYellowHighC {
                level = maxLevel(level, .yellow)
            }
        }

        if log.pain >= rules.painRed || log.hasBleeding {
            level = maxLevel(level, .red)
        } else if log.pain >= rules.painYellow {
            level = maxLevel(level, .yellow)
        }

        if log.stoolCount >= rules.diarrheaRedPerDay || log.vomitCount >= rules.vomitRedPerDay {
            level = maxLevel(level, .red)
        } else if log.stoolCount >= rules.diarrheaYellowLow && log.stoolCount <= rules.diarrheaYellowHigh {
            level = maxLevel(level, .yellow)
        } else if log.vomitCount >= 1 {
            level = maxLevel(level, .yellow)
        }

        if log.cipn >= rules.cipnRed {
            level = maxLevel(level, .red)
        } else if log.cipn >= rules.cipnYellowLow && log.cipn <= rules.cipnYellowHigh {
            level = maxLevel(level, .yellow)
        }

        if log.hfsGrade >= 3 {
            level = maxLevel(level, .red)
        } else if log.hfsGrade == 2 {
            level = maxLevel(level, .yellow)
        }

        return level
    }

    func feedback(for level: RiskLevel) -> String {
        switch level {
        case .green: CopyStrings.riskGreen
        case .yellow: CopyStrings.riskYellow
        case .red: CopyStrings.riskRed
        }
    }

    private func maxLevel(_ a: RiskLevel, _ b: RiskLevel) -> RiskLevel {
        let order: [RiskLevel] = [.green, .yellow, .red]
        let ai = order.firstIndex(of: a) ?? 0
        let bi = order.firstIndex(of: b) ?? 0
        return order[max(ai, bi)]
    }
}

struct OstomyRiskEvaluator {
    let rules: OstomyRiskRules

    init(rules: OstomyRiskRules? = RiskRulesRepository.shared.catalog?.ostomyRules) {
        self.rules = rules ?? OstomyRiskRules(baselineDays: 14, emptiesIncreaseYellow: 2, emptiesIncreaseRed: 4)
    }

    func evaluate(today: OstomyLog, history: [OstomyLog]) -> RiskLevel {
        let recent = history
            .filter { $0.date < today.date }
            .sorted { $0.date > $1.date }
            .prefix(rules.baselineDays)

        guard recent.count >= 7 else { return .green }

        let baseline = recent.map(\.emptiesCount).sorted()
        let median = baseline[baseline.count / 2]
        let delta = today.emptiesCount - median

        if today.hasLeakage && (today.skinStatus?.contains("糜烂") == true || today.skinStatus?.contains("重度") == true) {
            return .red
        }
        if delta >= rules.emptiesIncreaseRed || today.consistency == .watery && today.nighttimeEmpties >= 2 {
            return .red
        }
        if delta >= rules.emptiesIncreaseYellow || today.hasLeakage {
            return .yellow
        }
        return .green
    }
}
