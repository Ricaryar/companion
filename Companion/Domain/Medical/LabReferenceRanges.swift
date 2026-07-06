import Foundation

struct LabReferenceRangeValue: Codable, Equatable {
    var low: Double
    var high: Double
}

/// 常见生化/肿瘤检验默认参考区间（与前海泰康等医院报告一致，用户可在设置中覆盖）
enum LabReferenceRanges {
    static func defaultRange(for labType: String) -> (low: Double, high: Double)? {
        switch LabTypeNormalizer.code(for: labType) {
        case "CEA": return (0, 5.0)
        case "CA199": return (0, 37.0)
        case "CA125": return (0, 35.0)
        case "WBC": return (3.5, 9.5)
        case "RBC": return (4.3, 5.8)
        case "ANC": return (1.8, 6.3)
        case "Hb": return (130, 175)
        case "PLT": return (125, 350)
        case "MCV": return (82, 100)
        case "MCH": return (27, 34)
        case "MCHC": return (316, 354)
        case "HCT": return (40, 50)
        case "NEU%": return (40, 75)
        case "LYM%": return (20, 50)
        case "MONO%": return (3, 10)
        case "EOS%": return (0.4, 8.0)
        case "BASO%": return (0, 1.0)
        case "LYM#": return (1.1, 3.2)
        case "MONO#": return (0.1, 0.6)
        case "EO#": return (0.02, 0.52)
        case "BASO#": return (0, 0.06)
        case "RDW_SD": return (37, 54)
        case "RDW_CV": return (11, 15)
        case "PDW": return (9, 17)
        case "MPV": return (9.4, 12.5)
        case "PCT": return (0.1, 0.28)
        case "Na": return (137.0, 147.0)
        case "Ca": return (2.11, 2.52)
        case "P": return (0.85, 1.51)
        case "Cl": return (99.0, 110.0)
        case "K": return (3.50, 5.30)
        case "Mg": return (0.75, 1.02)
        case "TBIL": return (0, 26.0)
        case "DBIL": return (0, 8.0)
        case "IBIL": return (0, 18.0)
        case "TP": return (65.0, 85.0)
        case "ALB": return (40.0, 55.0)
        case "GLOB": return (20.0, 40.0)
        case "AG": return (1.5, 2.5)
        case "ALT": return (9.0, 50.0)
        case "AST": return (15.0, 40.0)
        case "GGT": return (10, 60)
        case "ALP": return (45.0, 125.0)
        case "Urea": return (1.70, 8.30)
        case "Cr": return (57, 115)
        case "UA": return (202, 416)
        case "CO2": return (22.0, 29.0)
        case "eGFR": return (90, 999)
        default: return nil
        }
    }

    static func effectiveRange(for labType: String) -> (low: Double, high: Double)? {
        let code = LabTypeNormalizer.code(for: labType)
        if let custom = AppSettings.shared.customReferenceRange(for: code) {
            return (custom.low, custom.high)
        }
        return defaultRange(for: labType)
    }

    static func isOutOfRange(value: Double, low: Double?, high: Double?, labType: String) -> Bool {
        let effectiveLow = low ?? effectiveRange(for: labType)?.low
        let effectiveHigh = high ?? effectiveRange(for: labType)?.high
        if let effectiveLow, value < effectiveLow { return true }
        if let effectiveHigh, value > effectiveHigh, effectiveHigh < 500 { return true }
        return false
    }

    static func rangeLabel(for labType: String, low: Double?, high: Double?) -> String? {
        let range = effectiveRange(for: labType)
        let lo = low ?? range?.low
        let hi = high ?? range?.high
        guard let lo, let hi else { return nil }
        if hi >= 500 { return "≥ \(format(lo))" }
        return "\(format(lo)) – \(format(hi))"
    }

    private static func format(_ v: Double) -> String {
        v == floor(v) ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
