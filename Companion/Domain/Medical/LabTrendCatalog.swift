import Foundation

struct TrendLabMetric: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let chineseName: String
    let defaultUnit: String
    let category: TrendLabCategory

    var displayName: String { "\(chineseName)（\(code)）" }
    var shortLabel: String { chineseName }
}

enum TrendLabCategory: String, CaseIterable {
    case tumor = "肿瘤标志物"
    case electrolyte = "电解质"
    case liver = "肝功能"
    case kidney = "肾功能"
    case blood = "血常规"
}

enum LabTrendCatalog {
    static let defaultTrackedCodes = ["CEA", "CA199", "ALT", "AST", "ALB"]

    static let all: [TrendLabMetric] = [
        TrendLabMetric(code: "CEA", chineseName: "癌胚抗原", defaultUnit: "ng/mL", category: .tumor),
        TrendLabMetric(code: "CA199", chineseName: "糖类抗原19-9", defaultUnit: "U/mL", category: .tumor),
        TrendLabMetric(code: "CA125", chineseName: "糖类抗原125", defaultUnit: "U/mL", category: .tumor),
        TrendLabMetric(code: "WBC", chineseName: "白细胞", defaultUnit: "10^9/L", category: .blood),
        TrendLabMetric(code: "RBC", chineseName: "红细胞", defaultUnit: "10^12/L", category: .blood),
        TrendLabMetric(code: "ANC", chineseName: "中性粒细胞", defaultUnit: "10^9/L", category: .blood),
        TrendLabMetric(code: "Hb", chineseName: "血红蛋白", defaultUnit: "g/L", category: .blood),
        TrendLabMetric(code: "PLT", chineseName: "血小板", defaultUnit: "10^9/L", category: .blood),
        TrendLabMetric(code: "MCV", chineseName: "红细胞平均体积", defaultUnit: "fL", category: .blood),
        TrendLabMetric(code: "MCH", chineseName: "平均血红蛋白量", defaultUnit: "pg", category: .blood),
        TrendLabMetric(code: "MCHC", chineseName: "平均血红蛋白浓度", defaultUnit: "g/L", category: .blood),
        TrendLabMetric(code: "HCT", chineseName: "红细胞压积", defaultUnit: "%", category: .blood),
        TrendLabMetric(code: "NEU%", chineseName: "中性粒细胞%", defaultUnit: "%", category: .blood),
        TrendLabMetric(code: "LYM%", chineseName: "淋巴细胞%", defaultUnit: "%", category: .blood),
        TrendLabMetric(code: "MONO%", chineseName: "单核细胞%", defaultUnit: "%", category: .blood),
        TrendLabMetric(code: "EOS%", chineseName: "嗜酸性粒细胞%", defaultUnit: "%", category: .blood),
        TrendLabMetric(code: "BASO%", chineseName: "嗜碱性粒细胞%", defaultUnit: "%", category: .blood),
        TrendLabMetric(code: "LYM#", chineseName: "淋巴细胞", defaultUnit: "10^9/L", category: .blood),
        TrendLabMetric(code: "MONO#", chineseName: "单核细胞", defaultUnit: "10^9/L", category: .blood),
        TrendLabMetric(code: "EO#", chineseName: "嗜酸性粒细胞", defaultUnit: "10^9/L", category: .blood),
        TrendLabMetric(code: "BASO#", chineseName: "嗜碱性粒细胞", defaultUnit: "10^9/L", category: .blood),
        TrendLabMetric(code: "RDW_SD", chineseName: "红细胞分布宽度-SD", defaultUnit: "fL", category: .blood),
        TrendLabMetric(code: "RDW_CV", chineseName: "红细胞分布宽度-CV", defaultUnit: "%", category: .blood),
        TrendLabMetric(code: "PDW", chineseName: "血小板分布宽度", defaultUnit: "fL", category: .blood),
        TrendLabMetric(code: "MPV", chineseName: "平均血小板体积", defaultUnit: "fL", category: .blood),
        TrendLabMetric(code: "PCT", chineseName: "血小板压积", defaultUnit: "%", category: .blood),
        TrendLabMetric(code: "Na", chineseName: "钠", defaultUnit: "mmol/L", category: .electrolyte),
        TrendLabMetric(code: "K", chineseName: "钾", defaultUnit: "mmol/L", category: .electrolyte),
        TrendLabMetric(code: "Cl", chineseName: "氯", defaultUnit: "mmol/L", category: .electrolyte),
        TrendLabMetric(code: "Ca", chineseName: "钙", defaultUnit: "mmol/L", category: .electrolyte),
        TrendLabMetric(code: "Mg", chineseName: "镁", defaultUnit: "mmol/L", category: .electrolyte),
        TrendLabMetric(code: "P", chineseName: "磷", defaultUnit: "mmol/L", category: .electrolyte),
        TrendLabMetric(code: "TBIL", chineseName: "总胆红素", defaultUnit: "μmol/L", category: .liver),
        TrendLabMetric(code: "DBIL", chineseName: "直接胆红素", defaultUnit: "μmol/L", category: .liver),
        TrendLabMetric(code: "IBIL", chineseName: "间接胆红素", defaultUnit: "μmol/L", category: .liver),
        TrendLabMetric(code: "TP", chineseName: "总蛋白", defaultUnit: "g/L", category: .liver),
        TrendLabMetric(code: "ALB", chineseName: "白蛋白", defaultUnit: "g/L", category: .liver),
        TrendLabMetric(code: "GLOB", chineseName: "球蛋白", defaultUnit: "g/L", category: .liver),
        TrendLabMetric(code: "AG", chineseName: "白球比例", defaultUnit: "", category: .liver),
        TrendLabMetric(code: "ALT", chineseName: "丙氨酸氨基转移酶", defaultUnit: "U/L", category: .liver),
        TrendLabMetric(code: "AST", chineseName: "天门冬氨酸氨基转移酶", defaultUnit: "U/L", category: .liver),
        TrendLabMetric(code: "GGT", chineseName: "γ-谷氨酰基转移酶", defaultUnit: "U/L", category: .liver),
        TrendLabMetric(code: "ALP", chineseName: "碱性磷酸酶", defaultUnit: "U/L", category: .liver),
        TrendLabMetric(code: "Urea", chineseName: "尿素", defaultUnit: "mmol/L", category: .kidney),
        TrendLabMetric(code: "Cr", chineseName: "肌酐", defaultUnit: "μmol/L", category: .kidney),
        TrendLabMetric(code: "UA", chineseName: "尿酸", defaultUnit: "μmol/L", category: .kidney),
        TrendLabMetric(code: "CO2", chineseName: "二氧化碳结合力", defaultUnit: "mmol/L", category: .kidney),
        TrendLabMetric(code: "eGFR", chineseName: "肾小球滤过率", defaultUnit: "mL/min", category: .kidney),
    ]

    static func metric(for code: String) -> TrendLabMetric? {
        all.first { $0.code == LabTypeNormalizer.code(for: code) }
    }

    static func chineseName(for code: String) -> String {
        metric(for: code)?.chineseName ?? code
    }

    static func displayName(for code: String) -> String {
        metric(for: code)?.displayName ?? code
    }
}
