import Foundation

/// 深圳理工等：项目[CODE] 方法 结果 单位 参考区间
/// 支持整行、多行、全文扫描（不依赖列坐标）
enum BracketLabLineParser {

    struct ParsedRow {
        let code: String
        let value: Double
        let unit: String
        let refLow: Double?
        let refHigh: Double?
        let rawLine: String
    }

    private struct CodeAnchor {
        let code: String
        let bracket: String
        let chinese: String?
    }

    /// 检验报告方括号缩写 → 应用内指标 code（含 %/# 后缀）
    private static let bracketToCode: [String: String] = [
        "HGB": "Hb", "HB": "Hb",
        "GLB": "GLOB", "UREA": "Urea", "A/G": "AG",
        "NEU#": "ANC",
        "NBU%": "NEU%", "NBU％": "NEU%",
        "RBC": "RBC", "MCV": "MCV", "MCH": "MCH", "MCHC": "MCHC", "HCT": "HCT",
        "WBC": "WBC", "PLT": "PLT",
        "NEU%": "NEU%", "NEU％": "NEU%",
        "LYM%": "LYM%", "LYM％": "LYM%",
        "MONO%": "MONO%", "MONO％": "MONO%",
        "EOS%": "EOS%", "EOS％": "EOS%",
        "BASO%": "BASO%", "BASO％": "BASO%",
        "LYM#": "LYM#", "MONO#": "MONO#", "EO#": "EO#", "BASO#": "BASO#",
        "RDW-SD": "RDW_SD", "RDWSD": "RDW_SD",
        "RDW-CV": "RDW_CV", "RDWCV": "RDW_CV", "RDW-CY": "RDW_CV",
        "PDW": "PDW", "MPV": "MPV", "PCT": "PCT",
    ]

    private static let bracketCodePattern = #"[A-Za-z0-9/%.#\-]+"#

    private static let anchors: [CodeAnchor] = [
        CodeAnchor(code: "K", bracket: "K", chinese: "钾"),
        CodeAnchor(code: "Na", bracket: "Na", chinese: "钠"),
        CodeAnchor(code: "Cl", bracket: "Cl", chinese: "氯"),
        CodeAnchor(code: "Ca", bracket: "Ca", chinese: "钙"),
        CodeAnchor(code: "P", bracket: "P", chinese: "磷"),
        CodeAnchor(code: "TP", bracket: "TP", chinese: "总蛋白"),
        CodeAnchor(code: "ALB", bracket: "ALB", chinese: "白蛋白"),
        CodeAnchor(code: "GLOB", bracket: "GLB", chinese: "球蛋白"),
        CodeAnchor(code: "AG", bracket: "A/G", chinese: "白球"),
        CodeAnchor(code: "TBIL", bracket: "TBIL", chinese: "总胆红素"),
        CodeAnchor(code: "DBIL", bracket: "DBIL", chinese: "直接胆红素"),
        CodeAnchor(code: "IBIL", bracket: "IBIL", chinese: "间接胆红素"),
        CodeAnchor(code: "ALT", bracket: "ALT", chinese: "丙氨酸"),
        CodeAnchor(code: "AST", bracket: "AST", chinese: "天门冬"),
        CodeAnchor(code: "GGT", bracket: "GGT", chinese: "谷氨酰"),
        CodeAnchor(code: "ALP", bracket: "ALP", chinese: "碱性磷酸酶"),
        CodeAnchor(code: "Urea", bracket: "UREA", chinese: "尿素"),
        CodeAnchor(code: "Cr", bracket: "Cr", chinese: "肌酐"),
        CodeAnchor(code: "UA", bracket: "UA", chinese: "尿酸"),
        CodeAnchor(code: "CO2", bracket: "CO2", chinese: "二氧化碳"),
        CodeAnchor(code: "CEA", bracket: "CEA", chinese: "癌胚抗原"),
        CodeAnchor(code: "CA199", bracket: "CA199", chinese: "糖类抗原19"),
        CodeAnchor(code: "WBC", bracket: "WBC", chinese: "白细胞"),
        CodeAnchor(code: "RBC", bracket: "RBC", chinese: "红细胞"),
        CodeAnchor(code: "Hb", bracket: "HGB", chinese: "血红蛋白"),
        CodeAnchor(code: "PLT", bracket: "PLT", chinese: "血小板"),
        CodeAnchor(code: "MCV", bracket: "MCV", chinese: "红细胞平均体积"),
        CodeAnchor(code: "MCH", bracket: "MCH", chinese: "平均血红蛋白"),
        CodeAnchor(code: "MCHC", bracket: "MCHC", chinese: "平均血红蛋白浓度"),
        CodeAnchor(code: "HCT", bracket: "HCT", chinese: "红细胞压积"),
        CodeAnchor(code: "NEU%", bracket: "NEU%", chinese: "中性粒细胞百分比"),
        CodeAnchor(code: "LYM%", bracket: "LYM%", chinese: "淋巴细胞百分比"),
        CodeAnchor(code: "MONO%", bracket: "MONO%", chinese: "单核细胞百分比"),
        CodeAnchor(code: "EOS%", bracket: "EOS%", chinese: "嗜酸性粒细胞百分比"),
        CodeAnchor(code: "BASO%", bracket: "BASO%", chinese: "嗜碱性粒细胞百分比"),
        CodeAnchor(code: "ANC", bracket: "NEU#", chinese: nil),
        CodeAnchor(code: "LYM#", bracket: "LYM#", chinese: "淋巴细胞"),
        CodeAnchor(code: "MONO#", bracket: "MONO#", chinese: "单核细胞"),
        CodeAnchor(code: "EO#", bracket: "EO#", chinese: "嗜酸性粒细胞"),
        CodeAnchor(code: "BASO#", bracket: "BASO#", chinese: "嗜碱性粒细胞"),
        CodeAnchor(code: "RDW_SD", bracket: "RDW-SD", chinese: "红细胞分布宽度"),
        CodeAnchor(code: "RDW_CV", bracket: "RDW-CV", chinese: "红细胞分布宽度"),
        CodeAnchor(code: "PDW", bracket: "PDW", chinese: "血小板分布宽度"),
        CodeAnchor(code: "MPV", bracket: "MPV", chinese: "平均血小板体积"),
        CodeAnchor(code: "PCT", bracket: "PCT", chinese: "血小板压积"),
    ]

    /// 逐行解析
    static func parse(lines: [String]) -> [ParsedRow] {
        let normalized = lines.map { normalizeText($0) }
        let merged = mergeBracketLines(normalized)
        return dedupe(parseRows(from: merged))
    }

    /// 全文逐项扫描（Vision 拆行时仍能找到 [ALT]…31.9…9~50）
    static func parseFullText(_ text: String) -> [ParsedRow] {
        let normalized = normalizeText(text)
        var results: [ParsedRow] = []

        for anchor in anchors {
            if let row = findInFullText(anchor: anchor, text: normalized) {
                results.append(row)
            }
        }
        return dedupe(results)
    }

    /// 合并三种策略，取最全；血常规分列版面优先用专用解析
    static func parseAll(lines: [String], fullText: String) -> [ParsedRow] {
        let normalized = normalizeText(fullText)
        if isCBCReport(normalized) {
            let split = parseSplitColumnLayout(fullText)
            if split.count >= 10 {
                return dedupe(split)
            }
        }
        let a = parse(lines: lines)
        let b = parseFullText(fullText)
        let c = parseByIndexAlignment(fullText)
        return dedupe(a + b + c)
    }

    /// 深圳理工总医院等：Vision 读出「项目名 | 结果 | 单位 | 参考区间」四列分行排列
    static func parseSplitColumnLayout(_ text: String) -> [ParsedRow] {
        let normalized = normalizeText(text)
        guard isCBCReport(normalized) else { return [] }

        let lines = normalized.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let refRanges = extractOrderedReferenceRanges(from: normalized)
        var itemRows: [(code: String, rawValue: String)] = []

        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard let code = extractCodeFromLine(line) else {
                index += 1
                continue
            }

            var rawValue: String?
            if let inline = extractInlineValue(from: line) {
                rawValue = inline
            } else if index + 1 < lines.count {
                let next = lines[index + 1]
                if !isSectionHeader(next), !isUnitOnlyLine(next), extractCodeFromLine(next) == nil {
                    rawValue = next
                    index += 1
                }
            }

            if let rawValue {
                itemRows.append((code, rawValue))
            }
            index += 1
        }

        guard itemRows.count >= 4 else { return [] }

        var results: [ParsedRow] = []
        for (idx, item) in itemRows.enumerated() {
            let ref = idx < refRanges.count ? refRanges[idx] : nil
            guard let value = cleanResultValue(item.rawValue, code: item.code, refRange: ref) else { continue }
            results.append(ParsedRow(
                code: item.code,
                value: value,
                unit: defaultUnit(for: item.code),
                refLow: ref?.low,
                refHigh: ref?.high,
                rawLine: "[\(item.code)] \(value)"
            ))
        }
        return results
    }

    private static func extractCodeFromLine(_ line: String) -> String? {
        if let bracket = extractBracketCode(from: line), let code = normalizeCode(bracket) {
            return code
        }
        if line.range(of: #"RDW-SD"#, options: .regularExpression) != nil { return "RDW_SD" }
        if line.range(of: #"RDW-CV|RDW-CY"#, options: .regularExpression) != nil { return "RDW_CV" }
        if line.range(of: #"\[PD\b|血小板体积分布宽度"#, options: .regularExpression) != nil { return "PDW" }
        if line.range(of: #"\[BASO[%#:]|嗜碱.*\[BAS"#, options: .regularExpression) != nil {
            if line.contains("#") || line.contains(":") { return "BASO#" }
            return "BASO%"
        }
        return nil
    }

    private static func extractInlineValue(from line: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: #"\]\s*([+\-]?[\d\s.&¥『』↑↓]+)"#),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let r = Range(match.range(at: 1), in: line) {
            let candidate = String(line[r]).trimmingCharacters(in: .whitespaces)
            if parseFlexibleNumber(candidate) != nil { return candidate }
        }
        if line.range(of: #"血小板体积分布宽度"#, options: .regularExpression) != nil,
           let regex = try? NSRegularExpression(pattern: #"(\d+\.?\d*)\s*$"#),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let r = Range(match.range(at: 1), in: line) {
            return String(line[r])
        }
        if let regex = try? NSRegularExpression(pattern: #"RDW-SD[A-Z]?\]?\s*J?\]?(\d+\.?\d*)"#),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let r = Range(match.range(at: 1), in: line) {
            return String(line[r])
        }
        if let regex = try? NSRegularExpression(pattern: #"#\]?(\d+\.?\d*)"#),
           line.contains("#"),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let r = Range(match.range(at: 1), in: line) {
            return String(line[r])
        }
        return nil
    }

    private static func extractOrderedReferenceRanges(from text: String) -> [(low: Double, high: Double)] {
        let scrubbed = scrubPowerUnits(text)
        let pattern = #"(\d+\.?\d*)\s*[~～\-—]\s*(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = scrubbed as NSString
        var ranges: [(low: Double, high: Double)] = []

        for match in regex.matches(in: scrubbed, range: NSRange(location: 0, length: ns.length)) {
            guard match.numberOfRanges >= 3,
                  let r1 = Range(match.range(at: 1), in: scrubbed),
                  let r2 = Range(match.range(at: 2), in: scrubbed),
                  let lo = Double(scrubbed[r1]),
                  let hi = Double(scrubbed[r2]),
                  lo <= hi else { continue }
            if isUnitRange(lo: lo, hi: hi) { continue }
            if lo == 10, hi == 9 { continue }
            if lo == 10, hi == 12 { continue }
            ranges.append((lo, hi))
        }
        return ranges
    }

    private static func isUnitRange(lo: Double, hi: Double) -> Bool {
        (lo == 10 && (hi == 9 || hi == 12)) || (lo >= 9 && lo <= 10 && hi <= 12 && hi > lo && hi - lo <= 3)
    }

    private static func isSectionHeader(_ line: String) -> Bool {
        line.range(of: #"^(检验项目|结果|单位|参考区间|样本|备注|采集|接收|审核|检验时间|仪器)"#, options: .regularExpression) != nil
            || line.range(of: #"^项目[：:]"#, options: .regularExpression) != nil
            || line.contains("检验报告单")
            || line.contains("深圳理工大学")
            || line.range(of: #"^(性别|门诊号码|样本类型|样本号|医生|检验者|接收者|审核者)"#, options: .regularExpression) != nil
    }

    private static func isUnitOnlyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed == "g/l" || trimmed == "fl" || trimmed == "pg" || trimmed == "%" { return true }
        if trimmed == "wbcunit" || trimmed == "rbcunit" { return true }
        return trimmed.range(of: #"^10\s*[~～^]\s*(9|12)\s*/?\s*l?$"#, options: .regularExpression) != nil
            || trimmed.range(of: #"^i0\s*[~～^]\s*9"#, options: .regularExpression) != nil
    }

    private static func cleanResultValue(
        _ raw: String,
        code: String,
        refRange: (low: Double, high: Double)?
    ) -> Double? {
        guard let parsed = parseFlexibleNumber(raw) else { return nil }
        let value = refRange.map { chooseBestValue(parsed, code: code, ref: $0) ?? parsed } ?? parsed
        return isPlausible(value: value, code: code) ? value : nil
    }

    /// 结合参考区间，从原值与「去掉首位 1（↑ 误识）」的候选值中选最合理的一个
    private static func chooseBestValue(
        _ parsed: Double,
        code: String,
        ref: (low: Double, high: Double)
    ) -> Double? {
        var candidates = [parsed]
        if let stripped = stripLeadingOneMisread(parsed) { candidates.append(stripped) }

        let plausible = candidates.filter { isPlausible(value: $0, code: code) }
        guard !plausible.isEmpty else { return nil }

        let mid = (ref.low + ref.high) / 2
        let inRange = plausible.filter { $0 >= ref.low * 0.92 && $0 <= ref.high * 1.15 }

        if !inRange.isEmpty {
            return inRange.min { abs($0 - mid) < abs($1 - mid) }
        }
        // 原值明显不可能（如 RBC 15.97）时，才采用去掉首位 1 的修正
        if parsed > ref.high * 1.35 || (parsed > 100 && ref.high <= 100) {
            return plausible.min { abs($0 - mid) < abs($1 - mid) }
        }
        return parsed
    }

    private static func parseFlexibleNumber(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: #"^[+&¥『』↑↓lI丨|\s]+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: ",", with: ".")

        // Vision 把 ↑ 识成 "1 "/"4 " 等前缀：1 444→444、4 63.9→63.9
        if let regex = try? NSRegularExpression(pattern: #"^[1-9]\s+(\d+\.?\d*)"#),
           let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let r = Range(match.range(at: 1), in: s) {
            s = String(s[r])
        }

        if let regex = try? NSRegularExpression(pattern: #"(\d+\.?\d*)"#),
           let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let r = Range(match.range(at: 1), in: s) {
            return Double(s[r])
        }
        return nil
    }

    /// Vision 常把 ↑ 识成首位 1：15.97→5.97、138.2→38.2（不剥其它数字，避免 444→44）
    private static func stripLeadingOneMisread(_ value: Double) -> Double? {
        let text = value == floor(value) ? String(format: "%.0f", value) : String(value)
        guard text.hasPrefix("1"), text.count >= 3 else { return nil }
        let rest = String(text.dropFirst())
        if rest.hasPrefix(".") { return Double("0" + rest) }
        return Double(rest)
    }

    /// Vision 常把表格读成「先整列项目名、再整列数值」，按出现顺序 zip 对齐
    static func parseByIndexAlignment(_ text: String) -> [ParsedRow] {
        let normalized = scrubPowerUnits(normalizeText(text))
        let codes = extractOrderedBracketCodes(from: normalized)
        let isCBC = isCBCReport(normalized)
        let minCodes = isCBC ? 4 : 5
        guard codes.count >= minCodes else { return [] }

        var tuples = extractOrderedResultTuples(from: normalized)
        if tuples.count < codes.count {
            let bareValues = extractOrderedBareValues(from: normalized)
            if bareValues.count >= codes.count {
                tuples = bareValues.map { (value: $0, unit: "", refLow: nil as Double?, refHigh: nil as Double?) }
            }
        }

        guard tuples.count >= minCodes else { return [] }
        let count = min(codes.count, tuples.count)
        guard count >= minCodes else { return [] }

        var results: [ParsedRow] = []
        for index in 0..<count {
            let code = codes[index]
            let tuple = tuples[index]
            guard isPlausible(value: tuple.value, code: code) else { continue }
            if let lo = tuple.refLow, let hi = tuple.refHigh,
               abs(tuple.value - lo) < 0.01 || abs(tuple.value - hi) < 0.01 { continue }
            results.append(ParsedRow(
                code: code,
                value: tuple.value,
                unit: tuple.unit.isEmpty ? defaultUnit(for: code) : tuple.unit,
                refLow: tuple.refLow,
                refHigh: tuple.refHigh,
                rawLine: "[\(code)] \(tuple.value) \(tuple.unit)"
            ))
        }
        return dedupe(results)
    }

    private static func extractOrderedBareValues(from text: String) -> [Double] {
        let pattern = #"(?<![\d.])(\d+\.\d{1,4})(?![\d.])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            Double(ns.substring(with: $0.range(at: 1)))
        }
    }

    private static func extractOrderedBracketCodes(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\[\s*(\#(bracketCodePattern))\s*\]"#) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            let raw = String(text[r])
            return normalizeCode(raw) ?? normalizeCode(fixOCRCode(raw))
        }
    }

    private static func extractOrderedResultTuples(from text: String) -> [(value: Double, unit: String, refLow: Double?, refHigh: Double?)] {
        let scrubbed = scrubPowerUnits(text)
        let unitGroup = #"(?:%|fL|pg|g/L|mmol/L|umol/L|μmol/L|mg/L|ng/mL|U/L|u/L|10\^?\d*/L)?"#
        let pattern = #"(\d+\.?\d*)\s*\#(unitGroup)\s*(\d+\.?\d*)\s*[~～\-—]\s*(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = scrubbed as NSString
        return regex.matches(in: scrubbed, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard let vR = Range(match.range(at: 1), in: scrubbed),
                  let value = Double(scrubbed[vR]) else { return nil }
            var unit = ""
            if match.numberOfRanges >= 3, let uR = Range(match.range(at: 2), in: scrubbed) {
                unit = normalizeUnit(String(scrubbed[uR]))
            }
            var refLow: Double?
            var refHigh: Double?
            if match.numberOfRanges >= 5,
               let loR = Range(match.range(at: 3), in: scrubbed),
               let hiR = Range(match.range(at: 4), in: scrubbed),
               let lo = Double(scrubbed[loR]),
               let hi = Double(scrubbed[hiR]),
               lo <= hi {
                refLow = lo
                refHigh = hi
            }
            return (value, unit, refLow, refHigh)
        }
    }

    private static func fixOCRCode(_ raw: String) -> String {
        let upper = raw.uppercased()
        switch upper {
        case "TB1L", "TBIL": return "TBIL"
        case "AL1": return "ALT"
        case "GLB": return "GLOB"
        case "NEU％", "NEU%", "NBU%", "NBU％": return "NEU%"
        case "LYM％", "LYM%": return "LYM%"
        case "MONO％", "MONO%": return "MONO%"
        case "EOS％", "EOS%": return "EOS%"
        case "BASO％", "BASO%", "BAS0%", "BAS0％": return "BASO%"
        case "BASO#", "BASO:": return "BASO#"
        case "RDW-CY": return "RDW-CV"
        default:
            return raw.replacingOccurrences(of: "％", with: "%")
                .replacingOccurrences(of: "BAS0", with: "BASO")
        }
    }

    private static func isCBCReport(_ text: String) -> Bool {
        text.range(of: #"血常规|\[WBC\]|\[HGB\]|\[RBC\]|\[NEU#\]|血常规五分类"#, options: .regularExpression) != nil
    }

    /// 去掉 10^9/L 等单位中的数字，避免误当成参考区间（如 WBC 参考被识成 10~9）
    private static func scrubPowerUnits(_ text: String) -> String {
        var s = text
        let replacements: [(String, String)] = [
            (#"10\s*\^?\s*9\s*/?\s*L"#, " WBCUNIT "),
            (#"10\s*[~～]\s*9\s*/?\s*L"#, " WBCUNIT "),
            (#"I0\s*[~～^]\s*9\s*/?\s*L"#, " WBCUNIT "),
            (#"10\s*\^?\s*12\s*/?\s*L"#, " RBCUNIT "),
            (#"10\s*[~～]\s*12\s*/?\s*L"#, " RBCUNIT "),
            (#"×\s*10\s*\^?\s*9"#, " WBCUNIT "),
            (#"×\s*10\s*\^?\s*12"#, " RBCUNIT "),
        ]
        for (pattern, replacement) in replacements {
            s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return s
    }

    // MARK: - Full text scan

    private static func findInFullText(anchor: CodeAnchor, text: String) -> ParsedRow? {
        let scrubbed = scrubPowerUnits(text)
        let b = NSRegularExpression.escapedPattern(for: anchor.bracket)
        let unitGroup = #"(?:%|fL|pg|U/L|u/L|g/L|mmol/L|umol/L|μmol/L|mg/L|WBCUNIT|RBCUNIT)?"#

        let bracketPatterns = [
            #"\[\s*\#(b)\s*\][\s\S]{0,200}?(\d+\.?\d*)\s*\#(unitGroup)[\s\S]{0,100}?(\d+\.?\d*)\s*[~～\-—]\s*(\d+\.?\d*)"#,
            #"\[\s*\#(b)\s*\][\s\S]{0,200}?(\d+\.?\d*)[\s\S]{0,100}?(\d+\.?\d*)\s*[~～\-—]\s*(\d+\.?\d*)"#
        ]

        for (idx, pattern) in bracketPatterns.enumerated() {
            if let row = matchPattern(pattern, in: scrubbed, anchor: anchor, hasUnit: idx == 0) {
                return row
            }
        }

        if let chinese = anchor.chinese {
            let cnPatterns = [
                #"\#(NSRegularExpression.escapedPattern(for: chinese))[\s\S]{0,200}?(\d+\.?\d*)\s*\#(unitGroup)[\s\S]{0,100}?(\d+\.?\d*)\s*[~～\-—]\s*(\d+\.?\d*)"#,
                #"\#(NSRegularExpression.escapedPattern(for: chinese))[\s\S]{0,200}?(\d+\.?\d*)[\s\S]{0,100}?(\d+\.?\d*)\s*[~～\-—]\s*(\d+\.?\d*)"#
            ]
            for (idx, pattern) in cnPatterns.enumerated() {
                if let row = matchPattern(pattern, in: scrubbed, anchor: anchor, hasUnit: idx == 0) {
                    return row
                }
            }
        }

        return nil
    }

    private static func matchPattern(
        _ pattern: String,
        in text: String,
        anchor: CodeAnchor,
        hasUnit: Bool
    ) -> ParsedRow? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text),
              let value = Double(text[valueRange]) else { return nil }

        var unit = defaultUnit(for: anchor.code)
        var refLow: Double?
        var refHigh: Double?

        if hasUnit, match.numberOfRanges >= 5,
           let uR = Range(match.range(at: 2), in: text),
           let loR = Range(match.range(at: 3), in: text),
           let hiR = Range(match.range(at: 4), in: text),
           let lo = Double(text[loR]),
           let hi = Double(text[hiR]),
           lo <= hi {
            unit = normalizeUnit(String(text[uR]))
            refLow = lo
            refHigh = hi
        } else if match.numberOfRanges >= 4,
                  let loR = Range(match.range(at: 2), in: text),
                  let hiR = Range(match.range(at: 3), in: text),
                  let lo = Double(text[loR]),
                  let hi = Double(text[hiR]),
                  lo <= hi {
            refLow = lo
            refHigh = hi
        }

        guard isPlausible(value: value, code: anchor.code) else { return nil }
        if let refLow, let refHigh, (abs(value - refLow) < 0.01 || abs(value - refHigh) < 0.01) {
            return nil
        }

        var snippet = ""
        if let matchRange = Range(match.range, in: text) {
            snippet = String(text[matchRange].prefix(120))
        }

        return ParsedRow(code: anchor.code, value: value, unit: unit, refLow: refLow, refHigh: refHigh, rawLine: snippet)
    }

    // MARK: - Line parse

    private static func parseRows(from lines: [String]) -> [ParsedRow] {
        lines.compactMap { parseLine($0) }
    }

    private static func parseLine(_ line: String) -> ParsedRow? {
        let cleaned = normalizeText(line)
        guard let bracket = extractBracketCode(from: cleaned),
              let code = normalizeCode(bracket) else { return nil }

        let anchor = anchors.first { $0.code == code } ?? CodeAnchor(code: code, bracket: bracket, chinese: nil)
        return findInFullText(anchor: anchor, text: cleaned) ?? findInFullText(anchor: anchor, text: cleaned + " ")
    }

    private static func mergeBracketLines(_ lines: [String]) -> [String] {
        var merged: [String] = []
        var index = 0
        while index < lines.count {
            var line = lines[index]
            if line.isEmpty { index += 1; continue }

            let looksLikeName = line.contains("[") || line.range(of: #"[\u4e00-\u9fff]{2,}"#, options: .regularExpression) != nil
            if looksLikeName, !lineHasResultAndRef(line), index + 1 < lines.count {
                var combined = line
                var span = 1
                while index + span < lines.count, span <= 4 {
                    combined += " " + lines[index + span]
                    if lineHasResultAndRef(combined) { break }
                    span += 1
                }
                merged.append(combined)
                index += span + 1
                continue
            }
            merged.append(line)
            index += 1
        }
        return merged
    }

    private static func lineHasResultAndRef(_ line: String) -> Bool {
        line.range(of: #"\d+\.?\d*\s*[~～]\s*\d+\.?\d*"#, options: .regularExpression) != nil
    }

    private static func extractBracketCode(from line: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: #"\[\s*(\#(bracketCodePattern))\s*\]"#),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let r = Range(match.range(at: 1), in: line) {
            return String(line[r])
        }
        if let regex = try? NSRegularExpression(pattern: #"\[\s*(\#(bracketCodePattern))\s*$"#),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let r = Range(match.range(at: 1), in: line) {
            return String(line[r])
        }
        return nil
    }

    private static func normalizeCode(_ bracket: String) -> String? {
        let fixed = fixOCRCode(bracket)
        if let mapped = bracketToCode[fixed] ?? bracketToCode[fixed.uppercased()] {
            return mapped
        }
        if fixed.uppercased() == "GLB" { return "GLOB" }
        if fixed.uppercased() == "UREA" { return "Urea" }
        if fixed == "A/G" || fixed.uppercased() == "AG" { return "AG" }
        return anchors.first { $0.bracket.uppercased() == fixed.uppercased() }?.code
            ?? anchors.first { $0.code.uppercased() == fixed.uppercased() }?.code
    }

    private static func normalizeText(_ text: String) -> String {
        var s = applyCharacterFixes(to: text)
        if let regex = try? NSRegularExpression(pattern: #"（\s*([A-Za-z0-9/]+)\s*）"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "[$1]")
        }
        if let regex = try? NSRegularExpression(pattern: #"（\s*([A-Za-z0-9/]+)\s*\]"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "[$1]")
        }
        if let regex = try? NSRegularExpression(pattern: #"\[(BASO%|NEU%|NBU%|LYM%|MONO%|EOS%)(?!\])"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "[$1]")
        }
        // 保留换行：分列 OCR 依赖「项目一行、结果一行」结构
        return s.split(separator: "\n", omittingEmptySubsequences: false)
            .map { normalizeLine(String($0)) }
            .joined(separator: "\n")
    }

    private static func applyCharacterFixes(to text: String) -> String {
        text
            .replacingOccurrences(of: "［", with: "[")
            .replacingOccurrences(of: "］", with: "]")
            .replacingOccurrences(of: "～", with: "~")
            .replacingOccurrences(of: "↑", with: " ")
            .replacingOccurrences(of: "↓", with: " ")
            .replacingOccurrences(of: "BAS0%", with: "BASO%")
            .replacingOccurrences(of: "BAS0", with: "BASO")
            .replacingOccurrences(of: "NBU%", with: "NEU%")
            .replacingOccurrences(of: "RDW-CY", with: "RDW-CV")
            .replacingOccurrences(of: "[BASO:", with: "[BASO#]")
            .replacingOccurrences(of: "RDW-SDJ", with: "RDW-SD]")
            .replacingOccurrences(of: "[PD ", with: "[PDW] ")
            .replacingOccurrences(of: "嗜破", with: "嗜碱")
    }

    /// 只压缩行内空白，不碰换行
    private static func normalizeLine(_ line: String) -> String {
        line.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func normalizeUnit(_ raw: String) -> String {
        let u = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if u.isEmpty || u == "wbcunit" { return "10^9/L" }
        if u == "rbcunit" { return "10^12/L" }
        if u.contains("u/l") { return "U/L" }
        if u.contains("g/l") { return "g/L" }
        if u.contains("mmol") { return "mmol/L" }
        if u.contains("umol") || u.contains("μmol") { return "μmol/L" }
        if u.contains("ng/ml") { return "ng/mL" }
        if u.contains("mg/l") { return "mg/L" }
        if u == "%" || u.contains("％") { return "%" }
        if u == "fl" { return "fL" }
        if u == "pg" { return "pg" }
        return raw
    }

    private static func defaultUnit(for code: String) -> String {
        LabTrendCatalog.metric(for: code)?.defaultUnit ?? ""
    }

    private static func isPlausible(value: Double, code: String) -> Bool {
        guard value > 0 else { return false }
        switch code {
        case "K", "Na", "Cl": return value > 0.5 && value < 200
        case "Ca", "Mg", "P": return value > 0.1 && value < 10
        case "TP", "ALB", "GLOB", "Hb", "MCHC": return value > 1 && value < 500
        case "AG": return value > 0.01 && value < 10
        case "ALT", "AST", "GGT", "ALP": return value > 0.1 && value < 5000
        case "TBIL", "DBIL", "IBIL", "Cr", "UA": return value > 0.01 && value < 2000
        case "Urea", "CO2": return value > 0.01 && value < 100
        case "WBC", "ANC", "LYM#", "MONO#", "PLT": return value > 0.01 && value < 2000
        case "RBC": return value > 0.5 && value < 10
        case "MCV", "RDW_SD", "PDW", "MPV": return value > 1 && value < 200
        case "MCH": return value > 1 && value < 50
        case "HCT", "NEU%", "LYM%", "MONO%", "EOS%", "BASO%", "RDW_CV": return value > 0.01 && value < 100
        case "EO#", "BASO#": return value > 0.001 && value < 5
        case "PCT": return value > 0.001 && value < 2
        default: return value < 10000
        }
    }

    private static func dedupe(_ rows: [ParsedRow]) -> [ParsedRow] {
        var seen = Set<String>()
        var out: [ParsedRow] = []
        for row in rows {
            guard !seen.contains(row.code) else { continue }
            seen.insert(row.code)
            out.append(row)
        }
        return out
    }
}
