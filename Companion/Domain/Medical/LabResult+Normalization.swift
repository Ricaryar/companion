import Foundation

extension LabResult {
    var normalizedLabType: String {
        LabTypeNormalizer.code(for: labType)
    }
}

enum LabTypeNormalizer {
    static func code(for raw: String) -> String {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let map: [String: String] = [
            "CEA": "CEA", "癌胚抗原": "CEA",
            "CA199": "CA199", "CA19-9": "CA199", "CA125": "CA125", "CA-125": "CA125", "糖类抗原125": "CA125",
            "WBC": "WBC", "白细胞": "WBC", "RBC": "RBC", "红细胞": "RBC",
            "ANC": "ANC", "NEU#": "ANC", "中性粒细胞": "ANC", "中性粒细胞绝对值": "ANC",
            "HB": "Hb", "HGB": "Hb", "血红蛋白": "Hb", "PLT": "PLT", "血小板": "PLT",
            "MCV": "MCV", "MCH": "MCH", "MCHC": "MCHC", "HCT": "HCT",
            "NEU%": "NEU%", "LYM%": "LYM%", "MONO%": "MONO%", "EOS%": "EOS%", "BASO%": "BASO%",
            "LYM#": "LYM#", "MONO#": "MONO#", "EO#": "EO#", "BASO#": "BASO#",
            "RDW-SD": "RDW_SD", "RDW_SD": "RDW_SD", "RDW-CV": "RDW_CV", "RDW_CV": "RDW_CV",
            "PDW": "PDW", "MPV": "MPV", "PCT": "PCT",
            "NA": "Na", "钠": "Na", "K": "K", "钾": "K",
            "CL": "Cl", "氯": "Cl", "CA": "Ca", "钙": "Ca",
            "MG": "Mg", "镁": "Mg", "P": "P", "磷": "P",
            "TBIL": "TBIL", "总胆红素": "TBIL",
            "DBIL": "DBIL", "直接胆红素": "DBIL",
            "IBIL": "IBIL", "间接胆红素": "IBIL",
            "TP": "TP", "总蛋白": "TP",
            "ALB": "ALB", "ALOB": "ALB", "白蛋白": "ALB",
            "GLOB": "GLOB", "GLB": "GLOB", "球蛋白": "GLOB",
            "A/G": "AG", "AG": "AG", "白球比例": "AG",
            "ALT": "ALT", "丙氨酸氨基转移酶": "ALT", "谷丙转氨酶": "ALT",
            "AST": "AST", "天门冬氨酸氨基转移酶": "AST", "谷草转氨酶": "AST",
            "GGT": "GGT", "γ-谷氨酰基转移酶": "GGT",
            "ALP": "ALP", "碱性磷酸酶": "ALP",
            "UREA": "Urea", "尿素": "Urea",
            "CR": "Cr", "CREA": "Cr", "肌酐": "Cr",
            "UA": "UA", "尿酸": "UA",
            "CO2-CP": "CO2", "CO2": "CO2", "二氧化碳结合力": "CO2",
            "EGFR": "eGFR", "肾小球滤过率": "eGFR",
        ]
        if let mapped = map[key] { return mapped }
        if let mapped = map[raw] { return mapped }
        return raw
    }

    static func isCEA(_ type: String) -> Bool {
        code(for: type) == "CEA"
    }

    static func displayName(for code: String) -> String {
        LabTrendCatalog.displayName(for: code)
    }
}
