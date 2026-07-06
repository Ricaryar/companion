import Foundation
import UIKit
import Vision

struct ExtractedLabValue: Equatable {
    let labType: String
    let value: Double
    let unit: String
    let refRangeLow: Double?
    let refRangeHigh: Double?
    let isAbnormal: Bool
}

struct ReportParseResult {
    let rawText: String
    let reportDate: Date
    let reportType: ReportType
    let suggestedTitle: String
    let labs: [ExtractedLabValue]
    let biomarkers: [String: String]
    /// 识别路径摘要，便于确认新逻辑已生效
    let ocrDebugSummary: String
}

private struct OCRToken {
    let text: String
    let midY: CGFloat
    let minX: CGFloat
    let maxX: CGFloat
}

private struct LabDefinition {
    let code: String
    let aliases: [String]
    let defaultUnit: String
    let plausibleRange: ClosedRange<Double>
}

/// 横向检验表「结果」列在版面中的 X 区间（Vision 归一化坐标 0–1）
private struct TableColumnBands {
    let resultMin: CGFloat
    let resultMax: CGFloat
    let referenceMin: CGFloat
}

enum ReportOCRService {
    private static let arrowPattern = "[↑↓⬆⬇↗↘↖↙←→▲▼△▽\\^vVLlHh＋\\-—~～]"
    /// 肿瘤标志物结果几乎均为小数；无小数时不应取整数 1（↑ 误识）
    private static let decimalPreferredCodes: Set<String> = ["CEA", "CA199", "CA125"]

    /// 前海泰康等标准生化报告：序号列与项目一一对应，用于锚定防错行
    private static let rowNumberToLabCode: [Int: String] = [
        1: "Na", 2: "Ca", 3: "P", 4: "Cl", 5: "K", 6: "Mg",
        7: "TBIL", 8: "DBIL", 9: "IBIL", 10: "TP", 11: "ALB", 12: "GLOB", 13: "AG",
        14: "ALT", 15: "AST", 17: "GGT", 18: "ALP",
        19: "Urea", 20: "Cr", 21: "UA", 22: "CO2", 23: "eGFR"
    ]
    private static let skippedTableRowNumbers: Set<Int> = [16, 24, 25, 26]

    /// 匹配顺序：越靠前越优先（长名称/易混淆项先定义）
    private static let labDefinitions: [LabDefinition] = [
        LabDefinition(code: "CEA", aliases: ["CEA", "癌胚抗原"], defaultUnit: "ng/mL", plausibleRange: 0.1...500),
        LabDefinition(code: "CA199", aliases: ["CA199", "CA19-9", "糖类抗原19-9"], defaultUnit: "U/mL", plausibleRange: 0.1...100000),
        LabDefinition(code: "CA125", aliases: ["CA125", "糖类抗原125"], defaultUnit: "U/mL", plausibleRange: 0.1...5000),
        LabDefinition(code: "DBIL", aliases: ["DBIL", "直接胆红素"], defaultUnit: "μmol/L", plausibleRange: 0.1...100),
        LabDefinition(code: "IBIL", aliases: ["IBIL", "间接胆红素"], defaultUnit: "μmol/L", plausibleRange: 0.1...100),
        LabDefinition(code: "TBIL", aliases: ["TBIL", "总胆红素"], defaultUnit: "μmol/L", plausibleRange: 0.1...500),
        LabDefinition(code: "GLOB", aliases: ["GLOB", "GLB", "球蛋白"], defaultUnit: "g/L", plausibleRange: 5...80),
        LabDefinition(code: "ALB", aliases: ["ALB", "ALOB", "白蛋白"], defaultUnit: "g/L", plausibleRange: 15...60),
        LabDefinition(code: "TP", aliases: ["TP", "总蛋白"], defaultUnit: "g/L", plausibleRange: 40...100),
        LabDefinition(code: "ALT", aliases: ["ALT", "丙氨酸氨基转移酶", "谷丙转氨酶"], defaultUnit: "U/L", plausibleRange: 1...2000),
        LabDefinition(code: "AST", aliases: ["AST", "天门冬氨酸氨基转移酶", "谷草转氨酶"], defaultUnit: "U/L", plausibleRange: 1...2000),
        LabDefinition(code: "GGT", aliases: ["GGT", "γ-谷氨酰", "谷氨酰"], defaultUnit: "U/L", plausibleRange: 1...2000),
        LabDefinition(code: "ALP", aliases: ["ALP", "碱性磷酸酶"], defaultUnit: "U/L", plausibleRange: 1...2000),
        LabDefinition(code: "AG", aliases: ["A/G", "白球比例"], defaultUnit: "", plausibleRange: 0.1...5),
        LabDefinition(code: "eGFR", aliases: ["eGFR", "肾小球滤过", "EGFR"], defaultUnit: "mL/min", plausibleRange: 1...300),
        LabDefinition(code: "Urea", aliases: ["Urea", "UREA", "尿素"], defaultUnit: "mmol/L", plausibleRange: 0.5...30),
        LabDefinition(code: "Cr", aliases: ["CREA", "Cr", "肌酐"], defaultUnit: "μmol/L", plausibleRange: 10...500),
        LabDefinition(code: "UA", aliases: ["UA", "尿酸"], defaultUnit: "μmol/L", plausibleRange: 50...800),
        LabDefinition(code: "CO2", aliases: ["CO2-CP", "CO2", "二氧化碳"], defaultUnit: "mmol/L", plausibleRange: 10...40),
        LabDefinition(code: "WBC", aliases: ["WBC", "白细胞"], defaultUnit: "10^9/L", plausibleRange: 0.1...100),
        LabDefinition(code: "RBC", aliases: ["RBC", "红细胞"], defaultUnit: "10^12/L", plausibleRange: 0.5...10),
        LabDefinition(code: "ANC", aliases: ["ANC", "NEU#", "中性粒细胞绝对值"], defaultUnit: "10^9/L", plausibleRange: 0...50),
        LabDefinition(code: "Hb", aliases: ["Hb", "HGB", "血红蛋白"], defaultUnit: "g/L", plausibleRange: 30...220),
        LabDefinition(code: "PLT", aliases: ["PLT", "血小板"], defaultUnit: "10^9/L", plausibleRange: 1...1000),
        LabDefinition(code: "MCV", aliases: ["MCV", "红细胞平均体积"], defaultUnit: "fL", plausibleRange: 1...200),
        LabDefinition(code: "MCH", aliases: ["MCH", "平均血红蛋白"], defaultUnit: "pg", plausibleRange: 1...50),
        LabDefinition(code: "MCHC", aliases: ["MCHC", "平均血红蛋白浓度"], defaultUnit: "g/L", plausibleRange: 200...400),
        LabDefinition(code: "HCT", aliases: ["HCT", "红细胞压积"], defaultUnit: "%", plausibleRange: 1...70),
        LabDefinition(code: "NEU%", aliases: ["NEU%", "中性粒细胞百分比"], defaultUnit: "%", plausibleRange: 0.01...100),
        LabDefinition(code: "LYM%", aliases: ["LYM%", "淋巴细胞百分比"], defaultUnit: "%", plausibleRange: 0.01...100),
        LabDefinition(code: "MONO%", aliases: ["MONO%", "单核细胞百分比"], defaultUnit: "%", plausibleRange: 0.01...100),
        LabDefinition(code: "EOS%", aliases: ["EOS%", "嗜酸性粒细胞百分比"], defaultUnit: "%", plausibleRange: 0.01...100),
        LabDefinition(code: "BASO%", aliases: ["BASO%", "嗜碱性粒细胞百分比"], defaultUnit: "%", plausibleRange: 0...10),
        LabDefinition(code: "LYM#", aliases: ["LYM#", "淋巴细胞绝对值"], defaultUnit: "10^9/L", plausibleRange: 0.01...20),
        LabDefinition(code: "MONO#", aliases: ["MONO#", "单核细胞绝对值"], defaultUnit: "10^9/L", plausibleRange: 0.01...5),
        LabDefinition(code: "EO#", aliases: ["EO#", "嗜酸性粒细胞绝对值"], defaultUnit: "10^9/L", plausibleRange: 0.001...5),
        LabDefinition(code: "BASO#", aliases: ["BASO#", "嗜碱性粒细胞绝对值"], defaultUnit: "10^9/L", plausibleRange: 0...1),
        LabDefinition(code: "RDW_SD", aliases: ["RDW-SD", "RDW_SD"], defaultUnit: "fL", plausibleRange: 1...200),
        LabDefinition(code: "RDW_CV", aliases: ["RDW-CV", "RDW_CV"], defaultUnit: "%", plausibleRange: 1...50),
        LabDefinition(code: "PDW", aliases: ["PDW", "血小板分布宽度"], defaultUnit: "fL", plausibleRange: 1...50),
        LabDefinition(code: "MPV", aliases: ["MPV", "平均血小板体积"], defaultUnit: "fL", plausibleRange: 1...30),
        LabDefinition(code: "PCT", aliases: ["PCT", "血小板压积"], defaultUnit: "%", plausibleRange: 0.001...2),
        LabDefinition(code: "Na", aliases: ["Na", "NA", "钠"], defaultUnit: "mmol/L", plausibleRange: 100...160),
        LabDefinition(code: "K", aliases: ["K", "钾"], defaultUnit: "mmol/L", plausibleRange: 2...8),
        LabDefinition(code: "Cl", aliases: ["Cl", "CL", "氯"], defaultUnit: "mmol/L", plausibleRange: 80...120),
        LabDefinition(code: "Ca", aliases: ["Ca", "CA", "钙"], defaultUnit: "mmol/L", plausibleRange: 1...4),
        LabDefinition(code: "Mg", aliases: ["Mg", "MG", "镁"], defaultUnit: "mmol/L", plausibleRange: 0.3...2),
        LabDefinition(code: "P", aliases: ["P", "磷"], defaultUnit: "mmol/L", plausibleRange: 0.3...3),
    ]

    static func parseReport(from image: UIImage) async throws -> ReportParseResult {
        let normalized = image.normalizedUpOrientation()
        let (text, tokens) = try await recognizeTextWithLayout(from: normalized)
        let lines = mergeAdjacentPartialRows(groupIntoLines(tokens))
        let labs = extractLabs(from: text, lines: lines)
        let date = extractReportDate(from: text) ?? Date()
        let type = inferReportType(from: text)
        let title = suggestTitle(type: type, date: date, labs: labs)
        let biomarkers = extractBiomarkers(from: text)

        return ReportParseResult(
            rawText: text,
            reportDate: date,
            reportType: type,
            suggestedTitle: title,
            labs: labs,
            biomarkers: biomarkers,
            ocrDebugSummary: labsOCRDebugSummary
        )
    }

    private static var labsOCRDebugSummary = ""

    static func recognizeText(from image: UIImage) async throws -> String {
        let result = try await parseReport(from: image)
        return result.rawText
    }

    static func extractLabs(from text: String) -> [ExtractedLabValue] {
        let lineGroups = text.components(separatedBy: .newlines).map { line -> [OCRToken] in
            [OCRToken(text: line, midY: 0, minX: 0, maxX: 1)]
        }
        return extractLabs(from: text, lines: lineGroups)
    }

    static func extractBiomarkers(from text: String) -> [String: String] {
        var map: [String: String] = [:]
        if text.range(of: "(?i)MSI[- ]?H|dMMR|微卫星不稳定", options: .regularExpression) != nil {
            map["MSI"] = "MSI-H / dMMR"
        }
        if text.range(of: "(?i)RAS\\s*野生|RAS wild", options: .regularExpression) != nil {
            map["RAS"] = "野生型"
        }
        if text.range(of: "(?i)RAS\\s*突变|RAS mut", options: .regularExpression) != nil {
            map["RAS"] = "突变型"
        }
        if text.range(of: "(?i)HER2\\s*阳性|HER2\\s*\\+", options: .regularExpression) != nil {
            map["HER2"] = "阳性"
        }
        return map
    }

    // MARK: - Layout OCR

    private static func recognizeTextWithLayout(from image: UIImage) async throws -> (String, [OCRToken]) {
        guard let cgImage = image.cgImage else { return ("", []) }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                var tokens: [OCRToken] = []
                var lines: [String] = []

                for obs in observations {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    let box = obs.boundingBox
                    let token = OCRToken(text: candidate.string, midY: box.midY, minX: box.minX, maxX: box.maxX)
                    tokens.append(token)
                    lines.append(candidate.string)
                }

                continuation.resume(returning: (lines.joined(separator: "\n"), tokens))
            }
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func groupIntoLines(_ tokens: [OCRToken]) -> [[OCRToken]] {
        let sorted = tokens.sorted { a, b in
            if abs(a.midY - b.midY) > 0.015 { return a.midY > b.midY }
            return a.minX < b.minX
        }
        var lines: [[OCRToken]] = []
        var current: [OCRToken] = []
        var currentY: CGFloat?

        for token in sorted {
            if let y = currentY, abs(token.midY - y) > 0.038 {
                if !current.isEmpty { lines.append(current) }
                current = [token]
                currentY = token.midY
            } else {
                current.append(token)
                currentY = currentY ?? token.midY
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    /// Vision 常把「项目名[CODE]」与「结果 单位 参考区间」拆成相邻两行，合并后再解析
    private static func mergeAdjacentPartialRows(_ lines: [[OCRToken]]) -> [[OCRToken]] {
        guard lines.count > 1 else { return lines }
        var merged: [[OCRToken]] = []
        var index = 0

        while index < lines.count {
            let current = lines[index]
            let currentText = current.map(\.text).joined(separator: " ")

            if index + 1 < lines.count {
                let next = lines[index + 1]
                let nextText = next.map(\.text).joined(separator: " ")
                let currentY = current.map(\.midY).reduce(0, +) / CGFloat(max(current.count, 1))
                let nextY = next.map(\.midY).reduce(0, +) / CGFloat(max(next.count, 1))

                let hasBracket = currentText.range(of: #"\[[A-Za-z0-9/]+\]"#, options: .regularExpression) != nil
                    || currentText.range(of: #"[\u4e00-\u9fff]{2,}"#, options: .regularExpression) != nil
                let currentHasValue = currentText.range(of: #"\d+\.?\d*\s*[~～]"#, options: .regularExpression) != nil
                let nextHasValue = nextText.range(of: #"\d+\.?\d*"#, options: .regularExpression) != nil

                if abs(currentY - nextY) < 0.055, hasBracket, !currentHasValue, nextHasValue {
                    merged.append(current + next)
                    index += 2
                    continue
                }
            }

            merged.append(current)
            index += 1
        }
        return merged
    }

    // MARK: - Lab extraction

    private static func extractLabs(from text: String, lines: [[OCRToken]]) -> [ExtractedLabValue] {
        let normalized = normalizeOCRText(text)
        let textLines = buildOCRTextLines(lines: lines, rawText: normalized)
        let flatText = textLines.joined(separator: " ")
        let scanText = normalized + "\n" + flatText

        let bracketRows = BracketLabLineParser.parseAll(lines: textLines, fullText: scanText)
        let bracketLabs = bracketRowsToExtracted(bracketRows)

        let gridResults = extractLabsViaGridPipeline(lines: lines)
        let legacyResults = extractLabsLegacy(from: scanText, lines: lines)

        var merged = mergeLabCandidates(
            bracket: bracketLabs,
            grid: gridResults,
            legacy: legacyResults
        )
        merged = supplementMissingLabs(base: merged, text: scanText, lines: lines)

        labsOCRDebugSummary = "方括号 \(bracketLabs.count) · 表格 \(gridResults.count) · 合并 \(merged.count)"
        if bracketLabs.count >= 10, scanText.contains("血常规") || scanText.contains("[WBC]") {
            labsOCRDebugSummary += " · 分列版面"
        }
        return merged
    }

    /// 方括号结果优先；表格/legacy 只补空缺项
    private static func mergeLabCandidates(
        bracket: [ExtractedLabValue],
        grid: [ExtractedLabValue],
        legacy: [ExtractedLabValue]
    ) -> [ExtractedLabValue] {
        var byCode: [String: ExtractedLabValue] = [:]
        for lab in bracket { byCode[lab.labType] = lab }
        for lab in grid where byCode[lab.labType] == nil { byCode[lab.labType] = lab }
        for lab in legacy where byCode[lab.labType] == nil { byCode[lab.labType] = lab }
        return byCode.values.sorted { $0.labType < $1.labType }
    }

    private static func normalizeOCRText(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "［", with: "[")
            .replacingOccurrences(of: "］", with: "]")
            .replacingOccurrences(of: "～", with: "~")
            .replacingOccurrences(of: "BAS0%", with: "BASO%")
            .replacingOccurrences(of: "BAS0", with: "BASO")
            .replacingOccurrences(of: "[BASO:", with: "[BASO#]")
            .replacingOccurrences(of: "RDW-SDJ", with: "RDW-SD]")
            .replacingOccurrences(of: "[PD ", with: "[PDW] ")
            .replacingOccurrences(of: "嗜破", with: "嗜碱")
        // Vision 常把 [ALT] 识成 （ALT］
        if let regex = try? NSRegularExpression(pattern: #"（\s*([A-Za-z0-9/]+)\s*）"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "[$1]")
        }
        if let regex = try? NSRegularExpression(pattern: #"（\s*([A-Za-z0-9/]+)\s*\]"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "[$1]")
        }
        if let regex = try? NSRegularExpression(pattern: #"\[\s*([A-Za-z0-9/%.#\-]+)\s*）"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "[$1]")
        }
        if let regex = try? NSRegularExpression(pattern: #"\[(BASO%|NEU%|LYM%|MONO%|EOS%)(?!\])"#) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "[$1]")
        }
        // 常见 OCR 混淆
        let codeFixes = ["TB1L": "TBIL", "TBIL": "TBIL", "AL1": "ALT", "AST": "AST", "ALB": "ALB", "UREA": "UREA"]
        for (wrong, right) in codeFixes {
            s = s.replacingOccurrences(of: "[\(wrong)]", with: "[\(right)]", options: .caseInsensitive)
        }
        return s
    }

    private static func bracketRowsToExtracted(_ rows: [BracketLabLineParser.ParsedRow]) -> [ExtractedLabValue] {
        rows.compactMap { row in
            guard let def = labDefinitions.first(where: { $0.code == row.code }) else { return nil }
            let ref: (low: Double, high: Double)? = {
                if let lo = row.refLow, let hi = row.refHigh { return (lo, hi) }
                return LabReferenceRanges.effectiveRange(for: row.code).map { ($0.low, $0.high) }
            }()
            return buildLab(
                value: row.value,
                definition: def,
                text: row.rawLine,
                refRange: ref.map { (low: $0.0, high: $0.1) },
                isAbnormal: false
            )
        }
    }

    private static func buildOCRTextLines(lines: [[OCRToken]], rawText: String) -> [String] {
        var result: [String] = []
        for group in lines {
            let line = group.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { result.append(line) }
        }
        for line in rawText.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { result.append(t) }
        }
        return result
    }

    private static func supplementMissingLabs(
        base: [ExtractedLabValue],
        text: String,
        lines: [[OCRToken]]
    ) -> [ExtractedLabValue] {
        var seen = Set(base.map(\.labType))
        var merged = base

        for definition in labDefinitions where decimalPreferredCodes.contains(definition.code) {
            guard !seen.contains(definition.code) else { continue }
            if let lab = findLabInFullText(text, definition: definition) {
                merged.append(lab)
                seen.insert(definition.code)
            }
        }

        if isQianhaiNumberedTable(lines) {
            let legacy = extractLabsLegacy(from: text, lines: lines)
            for lab in legacy where !seen.contains(lab.labType) {
                merged.append(lab)
                seen.insert(lab.labType)
            }
        }

        return merged.sorted { $0.labType < $1.labType }
    }

    /// 虚拟表格：逐行扫描，一行一项，结果只从本行取
    private static func extractLabsViaGridPipeline(lines: [[OCRToken]]) -> [ExtractedLabValue] {
        let gridTokens = lines.map { row in
            row.map { LabTableGridOCR.Token(text: $0.text, midY: $0.midY, minX: $0.minX, maxX: $0.maxX) }
        }

        let defs = labDefinitions.map {
            (code: $0.code, aliases: $0.aliases, defaultUnit: $0.defaultUnit, plausibleRange: $0.plausibleRange)
        }

        let candidates = LabTableGridOCR.extractAllRows(
            from: gridTokens,
            definitions: defs,
            isHeaderRow: { isNonLabTableRow($0) },
            isSkippedRow: { text in
                isRatioRow(text)
                    || text.range(of: #"^(溶血|黄疸|脂血)"#, options: .regularExpression) != nil
            },
            parseNumber: parseNumericToken,
            parseRefRange: parseReferenceRange,
            matchName: gridMatchName,
            unitMatches: { code, unit, rowText in
                guard let def = labDefinitions.first(where: { $0.code == code }) else { return false }
                return valueMatchesExpectedUnit(1, definition: def, text: rowText + " " + unit)
            },
            isRefBandNumber: { value, text in isValueInReferenceBand(value, text: text) }
        )

        return candidates.map { c in
            let def = labDefinitions.first { $0.code == c.code }!
            let ref: (low: Double, high: Double)? = {
                if let lo = c.refLow, let hi = c.refHigh { return (lo, hi) }
                return LabReferenceRanges.effectiveRange(for: c.code).map { ($0.low, $0.high) }
            }()
            return buildLab(
                value: c.value,
                definition: def,
                text: c.rowCombined,
                refRange: ref.map { (low: $0.0, high: $0.1) },
                isAbnormal: false
            )
        }
    }

    private static func gridMatchName(_ code: String, nameText: String, aliases: [String]) -> Int {
        guard let def = labDefinitions.first(where: { $0.code == code }) else { return 0 }
        let combined = nameText

        if combined.range(of: #"\[\s*\#(NSRegularExpression.escapedPattern(for: code))\s*\]"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return 100
        }
        if code == "GLOB", combined.range(of: #"\[\s*GLB\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "Urea", combined.range(of: #"\[\s*UREA\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "AG", combined.range(of: #"\[\s*A/G\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "Cr", combined.range(of: #"\[\s*Cr\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "K", combined.range(of: #"\[\s*K\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "Na", combined.range(of: #"\[\s*Na\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "Cl", combined.range(of: #"\[\s*Cl\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "Ca", combined.range(of: #"(?:总钙|钙)\s*\[Ca\]"#, options: .regularExpression) != nil { return 100 }
        if code == "P", combined.range(of: #"(?:磷|无机磷)\s*\[P\]"#, options: .regularExpression) != nil { return 100 }
        if code == "TP", combined.range(of: #"\[\s*TP\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "ALB", combined.range(of: #"\[\s*ALB\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "TBIL", combined.range(of: #"\[\s*TBIL\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "DBIL", combined.range(of: #"\[\s*DBIL\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "IBIL", combined.range(of: #"\[\s*IBIL\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "UA", combined.range(of: #"\[\s*UA\s*\]"#, options: .regularExpression) != nil { return 100 }

        for alias in aliases where alias.count <= 5 {
            if combined.range(of: #"(?i)\b\#(NSRegularExpression.escapedPattern(for: alias))\b"#, options: .regularExpression) != nil {
                return 95
            }
        }

        if code == "ALT" {
            guard combined.range(of: #"(?i)丙氨酸|\[ALT\]|谷丙"#, options: .regularExpression) != nil else { return 0 }
            guard combined.range(of: #"(?i)天门冬|\[AST\]|谷草"#, options: .regularExpression) == nil else { return 0 }
            return 90
        }
        if code == "AST" {
            guard combined.range(of: #"(?i)天门冬|\[AST\]|谷草"#, options: .regularExpression) != nil else { return 0 }
            guard combined.range(of: #"(?i)丙氨酸|\[ALT\]|谷丙"#, options: .regularExpression) == nil else { return 0 }
            return 90
        }
        if code == "Hb" {
            guard combined.range(of: #"血红蛋白|\[HGB\]|\[Hb\]"#, options: .regularExpression) != nil else { return 0 }
            return 90
        }
        if code == "WBC", combined.range(of: #"\[WBC\]|白细胞"#, options: .regularExpression) != nil { return 90 }
        if code == "RBC", combined.range(of: #"\[RBC\]|红细胞"#, options: .regularExpression) != nil { return 90 }
        if code == "PLT", combined.range(of: #"\[PLT\]|血小板"#, options: .regularExpression) != nil { return 90 }
        if code == "ANC", combined.range(of: #"\[NEU#\]|NEU#"#, options: .regularExpression) != nil { return 95 }
        if code == "MCV", combined.range(of: #"\[MCV\]"#, options: .regularExpression) != nil { return 95 }
        if code == "MCHC", combined.range(of: #"\[MCHC\]"#, options: .regularExpression) != nil { return 95 }
        if ["NEU%", "LYM%", "MONO%", "EOS%", "BASO%", "LYM#", "MONO#", "EO#", "BASO#",
            "MCH", "HCT", "RDW_SD", "RDW_CV", "PDW", "MPV", "PCT"].contains(code),
           combined.range(of: #"\[\s*\#(NSRegularExpression.escapedPattern(for: code.replacingOccurrences(of: "_", with: "-")))\s*\]"#, options: .regularExpression) != nil {
            return 95
        }

        for alias in aliases where alias.count >= 3 {
            if combined.localizedCaseInsensitiveContains(alias) { return 75 }
        }
        return 0
    }

    private static func extractLabsLegacy(from text: String, lines: [[OCRToken]]) -> [ExtractedLabValue] {
        var results: [ExtractedLabValue] = []
        var seen = Set<String>()
        var consumedLineIndices = Set<Int>()
        let columnBands = detectResultColumnBands(from: lines)
        let useNumberedTable = isQianhaiNumberedTable(lines)

        // 深圳理工等：检验项目[CODE] 格式，逐行解析
        if isBracketFormatReport(text) {
            for (lineIndex, tokens) in lines.enumerated() {
                guard let lab = parseBracketTableRow(tokens, columnBands: columnBands),
                      !seen.contains(lab.labType) else { continue }
                results.append(lab)
                seen.insert(lab.labType)
                consumedLineIndices.insert(lineIndex)
            }
        }

        // 前海泰康 1–26 序号锚定（仅在有连续序号表时启用）
        if useNumberedTable {
            for (lineIndex, tokens) in lines.enumerated() {
                guard !consumedLineIndices.contains(lineIndex) else { continue }
                guard let rowNum = extractLeadingRowNumber(from: tokens) else { continue }
                guard !skippedTableRowNumbers.contains(rowNum),
                      let code = rowNumberToLabCode[rowNum],
                      let definition = labDefinitions.first(where: { $0.code == code }),
                      !seen.contains(code) else { continue }

                if let lab = parseTableRow(tokens, columnBands: columnBands, forcedDefinition: definition) {
                    results.append(lab)
                    seen.insert(lab.labType)
                    consumedLineIndices.insert(lineIndex)
                }
            }
        }

        for index in lines.indices {
            if consumedLineIndices.contains(index) { continue }

            if let lab = parseTableRow(lines[index], columnBands: columnBands),
               !seen.contains(lab.labType) {
                results.append(lab)
                seen.insert(lab.labType)
                consumedLineIndices.insert(index)
                continue
            }

            guard columnBands != nil,
                  lineHasLabAlias(tokens: lines[index]),
                  !rowHasResultInColumn(lines[index], bands: columnBands!) else { continue }

            for span in 1...1 where index + span < lines.count {
                let combinedTokens = (index...(index + span)).flatMap { lines[$0] }
                if strictAliasCount(in: combinedTokens) > 1 { continue }
                guard let lab = parseTableRow(combinedTokens, columnBands: columnBands),
                      !seen.contains(lab.labType) else { continue }
                results.append(lab)
                seen.insert(lab.labType)
                consumedLineIndices.formUnion(index...(index + span))
                break
            }
        }

        // 补全遗漏项：仅在行内明确出现项目名时提取
        let panelCodes: Set<String> = [
            "ALT", "AST", "ALP", "GGT", "ALB", "TP", "GLOB", "AG",
            "TBIL", "DBIL", "IBIL", "Na", "K", "Cl", "Ca", "Mg", "P",
            "Urea", "Cr", "UA", "CO2", "eGFR"
        ]
        for definition in labDefinitions where panelCodes.contains(definition.code) {
            guard !seen.contains(definition.code) else { continue }
            if let lab = findLabOnSingleLine(in: lines, definition: definition, columnBands: columnBands)
                ?? findLabInFullTextForEnzyme(text, definition: definition) {
                results.append(lab)
                seen.insert(definition.code)
            }
        }

        // 肿瘤标志物
        for definition in labDefinitions where decimalPreferredCodes.contains(definition.code) {
            guard !seen.contains(definition.code) else { continue }
            if let lab = findLabInFullText(text, definition: definition) {
                results.append(lab)
                seen.insert(definition.code)
            }
        }

        // 血常规：必须行内明确含项目名，避免误识；ANC 只认 [NEU#] 避免与百分比行混淆
        let bloodPanelCodes = ["WBC", "RBC", "ANC", "Hb", "PLT", "MCV", "MCH", "MCHC", "HCT",
                               "NEU%", "LYM%", "MONO%", "EOS%", "BASO%",
                               "LYM#", "MONO#", "EO#", "BASO#",
                               "RDW_SD", "RDW_CV", "PDW", "MPV", "PCT"]
        for definition in labDefinitions where bloodPanelCodes.contains(definition.code) {
            guard !seen.contains(definition.code) else { continue }
            guard textContainsExplicitBloodMarker(definition.code, text: text) else { continue }
            if let lab = findLabOnSingleLine(in: lines, definition: definition, columnBands: columnBands) {
                results.append(lab)
                seen.insert(definition.code)
            }
        }

        return results
    }

    private static func isBracketFormatReport(_ text: String) -> Bool {
        text.range(of: #"\[(WBC|RBC|HGB|PLT|MCV|NEU#|NEU%|ALT|AST|ALB|TP|K|Na|Cl|Ca|GLB|GLOB|TBIL|DBIL|IBIL|UREA|Cr|UA)\]"#, options: .regularExpression) != nil
            || text.range(of: #"丙氨酸氨基转移酶\s*\[ALT\]|天门冬氨酸氨基转移酶\s*\[AST\]|血常规"#, options: .regularExpression) != nil
    }

    private static func isQianhaiNumberedTable(_ lines: [[OCRToken]]) -> Bool {
        var hits = 0
        for tokens in lines {
            guard let n = extractLeadingRowNumber(from: tokens) else { continue }
            if rowNumberToLabCode[n] != nil { hits += 1 }
        }
        return hits >= 8
    }

    /// 解析「钾[K]」「丙氨酸氨基转移酶[ALT]」等带方括号缩写的行
    private static func parseBracketTableRow(
        _ tokens: [OCRToken],
        columnBands: TableColumnBands?
    ) -> ExtractedLabValue? {
        let combined = tokens.map(\.text).joined(separator: " ")
        if isNonLabTableRow(combined) || isRatioRow(combined) { return nil }
        guard let definition = bestDefinitionForBracketRow(tokens: tokens, combined: combined) else {
            return nil
        }
        if strictAliasCount(in: tokens) > 1 { return nil }

        let refRange = parseReferenceRange(in: combined) ?? LabReferenceRanges.effectiveRange(for: definition.code).map {
            (low: $0.low, high: $0.high)
        }

        if let value = extractValueAfterBracketAlias(combined, definition: definition) {
            return buildLab(value: value, definition: definition, text: combined, refRange: refRange, isAbnormal: false)
        }

        guard let value = extractResultFromRow(
            tokens: tokens,
            definition: definition,
            refRange: refRange,
            columnBands: columnBands
        ) else { return nil }

        return buildLab(value: value, definition: definition, text: combined, refRange: refRange, isAbnormal: false)
    }

    private static func bestDefinitionForBracketRow(tokens: [OCRToken], combined: String) -> LabDefinition? {
        var best: (LabDefinition, Int)?
        for definition in labDefinitions {
            let score = bracketRowMatchScore(definition: definition, tokens: tokens, combined: combined)
            guard score > 0 else { continue }
            if let current = best {
                if score > current.1 { best = (definition, score) }
            } else {
                best = (definition, score)
            }
        }
        return best?.0
    }

    private static func bracketRowMatchScore(definition: LabDefinition, tokens: [OCRToken], combined: String) -> Int {
        let code = definition.code
        let bracketPatterns = [
            #"\[\s*\#(NSRegularExpression.escapedPattern(for: code))\s*\]"#,
            #"\[\s*\#(NSRegularExpression.escapedPattern(for: code.uppercased()))\s*\]"#
        ]
        for pattern in bracketPatterns {
            if combined.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return 100
            }
        }
        if code == "GLOB", combined.range(of: #"\[\s*GLB\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "Urea", combined.range(of: #"\[\s*UREA\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "Cr", combined.range(of: #"\[\s*Cr\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "Hb", combined.range(of: #"\[\s*HGB\s*\]|\[\s*Hb\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "ANC", combined.range(of: #"\[\s*NEU#\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "RBC", combined.range(of: #"\[\s*RBC\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "WBC", combined.range(of: #"\[\s*WBC\s*\]"#, options: .regularExpression) != nil { return 100 }
        if code == "PLT", combined.range(of: #"\[\s*PLT\s*\]"#, options: .regularExpression) != nil { return 100 }
        return rowMatchScore(definition: definition, tokens: tokens, combined: combined)
    }

    /// 别名 [ALT] 后第一个合理数值（跳过检测方法列里的数字）
    private static func extractValueAfterBracketAlias(_ combined: String, definition: LabDefinition) -> Double? {
        let code = definition.code
        let aliasPattern: String
        switch code {
        case "GLOB": aliasPattern = #"(?:\[\s*GLB\s*\]|\[\s*GLOB\s*\])"#
        case "Urea": aliasPattern = #"(?:\[\s*UREA\s*\]|\[\s*Urea\s*\])"#
        case "Cr": aliasPattern = #"(?:\[\s*Cr\s*\]|\[\s*CREA\s*\])"#
        case "Hb": aliasPattern = #"(?:\[\s*HGB\s*\]|\[\s*Hb\s*\])"#
        case "ANC": aliasPattern = #"\[\s*NEU#\s*\]"#
        case "RBC": aliasPattern = #"\[\s*RBC\s*\]"#
        default:
            aliasPattern = #"\[\s*\#(NSRegularExpression.escapedPattern(for: code))\s*\]"#
        }
        let unitPattern = unitPatternFor(definition)
        let pattern = "(?i)\(aliasPattern)[^0-9]{0,90}?(\(unitPattern))"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = combined as NSString
        guard let match = regex.firstMatch(in: combined, range: NSRange(location: 0, length: ns.length)),
              let r = Range(match.range(at: 1), in: combined),
              let value = Double(combined[r]) else { return nil }
        let refRange = parseReferenceRange(in: combined)
        guard definition.plausibleRange.contains(value),
              !isReferenceValue(value, refRange: refRange),
              !isValueInReferenceBand(value, text: combined),
              valueMatchesExpectedUnit(value, definition: definition, text: combined) else { return nil }
        return value
    }

    private static func unitPatternFor(_ definition: LabDefinition) -> String {
        switch definition.code {
        case "ALT", "AST", "ALP", "GGT": return #"\d+\.?\d*"#
        case "ALB", "TP", "GLOB": return #"\d+\.?\d*"#
        case "Na", "K", "Cl", "Ca", "Mg", "P", "Urea", "CO2": return #"\d+\.?\d*"#
        case "TBIL", "DBIL", "IBIL", "Cr", "UA": return #"\d+\.?\d*"#
        case "AG": return #"\d+\.?\d*"#
        default: return #"\d+\.?\d*"#
        }
    }

    private static func textContainsExplicitBloodMarker(_ code: String, text: String) -> Bool {
        switch code {
        case "Hb":
            return text.range(of: #"血红蛋白|\[HGB\]|\[Hb\]|HGB(?!\s*AB)"#, options: .regularExpression) != nil
        case "WBC":
            return text.range(of: #"白细胞|\[WBC\]|WBC计数"#, options: .regularExpression) != nil
        case "RBC":
            return text.range(of: #"红细胞|\[RBC\]"#, options: .regularExpression) != nil
        case "PLT":
            return text.range(of: #"血小板|\[PLT\]"#, options: .regularExpression) != nil
        case "ANC":
            return text.range(of: #"\[NEU#\]|NEU#|中性粒细胞[^%\n]{0,12}#|\[NEU#\]"#, options: .regularExpression) != nil
        case "MCV": return text.range(of: #"\[MCV\]|红细胞平均体积"#, options: .regularExpression) != nil
        case "MCH": return text.range(of: #"\[MCH\]|平均血红蛋白(?!浓度)"#, options: .regularExpression) != nil
        case "MCHC": return text.range(of: #"\[MCHC\]|平均血红蛋白浓度"#, options: .regularExpression) != nil
        case "HCT": return text.range(of: #"\[HCT\]|红细胞压积"#, options: .regularExpression) != nil
        case "NEU%": return text.range(of: #"\[NEU%\]|NEU%"#, options: .regularExpression) != nil
        case "LYM%": return text.range(of: #"\[LYM%\]|LYM%"#, options: .regularExpression) != nil
        case "MONO%": return text.range(of: #"\[MONO%\]|MONO%"#, options: .regularExpression) != nil
        case "EOS%": return text.range(of: #"\[EOS%\]|EOS%"#, options: .regularExpression) != nil
        case "BASO%": return text.range(of: #"\[BASO%\]|BASO%"#, options: .regularExpression) != nil
        case "LYM#": return text.range(of: #"\[LYM#\]|LYM#"#, options: .regularExpression) != nil
        case "MONO#": return text.range(of: #"\[MONO#\]|MONO#"#, options: .regularExpression) != nil
        case "EO#": return text.range(of: #"\[EO#\]|EO#"#, options: .regularExpression) != nil
        case "BASO#": return text.range(of: #"\[BASO#\]|BASO#"#, options: .regularExpression) != nil
        case "RDW_SD": return text.range(of: #"\[RDW-SD\]|\[RDW_SD\]"#, options: .regularExpression) != nil
        case "RDW_CV": return text.range(of: #"\[RDW-CV\]|\[RDW_CV\]"#, options: .regularExpression) != nil
        case "PDW": return text.range(of: #"\[PDW\]"#, options: .regularExpression) != nil
        case "MPV": return text.range(of: #"\[MPV\]"#, options: .regularExpression) != nil
        case "PCT": return text.range(of: #"\[PCT\]"#, options: .regularExpression) != nil
        default: return false
        }
    }

    private static func findLabOnSingleLine(
        in lines: [[OCRToken]],
        definition: LabDefinition,
        columnBands: TableColumnBands?
    ) -> ExtractedLabValue? {
        for tokens in lines {
            let combined = tokens.map(\.text).joined(separator: " ")
            guard strictAliasCount(in: tokens) <= 1 else { continue }
            guard rowContains(definition, in: combined) else { continue }
            if lineHasMultipleLiverEnzymes(combined) { continue }
            if let lab = parseTableRow(tokens, columnBands: columnBands), lab.labType == definition.code {
                return lab
            }
        }
        return nil
    }

    /// 取行首序号列（Vision 坐标 minX 通常 < 0.15）
    private static func extractLeadingRowNumber(from tokens: [OCRToken]) -> Int? {
        let sorted = tokens.sorted { $0.minX < $1.minX }
        for token in sorted.prefix(4) where token.minX < 0.16 {
            let t = token.text.trimmingCharacters(in: .whitespaces)
            if let value = parseNumericToken(t),
               value >= 1, value <= 26, value == floor(value) {
                return Int(value)
            }
        }

        let combined = sorted.map(\.text).joined(separator: " ")
        if let regex = try? NSRegularExpression(pattern: #"^\s*(\d{1,2})\b"#),
           let match = regex.firstMatch(in: combined, range: NSRange(combined.startIndex..., in: combined)),
           let r = Range(match.range(at: 1), in: combined),
           let num = Int(combined[r]),
           num >= 1, num <= 26 {
            return num
        }
        return nil
    }

    /// 根据全表数值 token 的 X 坐标聚类，定位「结果」列（各行的结果在同一竖条带内）
    private static func detectResultColumnBands(from lines: [[OCRToken]]) -> TableColumnBands? {
        var resultXs: [CGFloat] = []

        for tokens in lines {
            let combined = tokens.map(\.text).joined(separator: " ")
            if isNonLabTableRow(combined) || isRatioRow(combined) { continue }
            guard lineHasLabAlias(tokens: tokens) else { continue }

            for token in tokens {
                guard let value = parseNumericToken(token.text) else { continue }
                if isLikelyRowIndex(value, in: combined) { continue }
                if isValueInReferenceBand(value, text: combined) { continue }
                if token.minX < 0.22 || token.minX > 0.62 { continue }
                resultXs.append(token.minX)
            }
        }

        guard resultXs.count >= 6 else { return nil }

        var buckets: [Int: [CGFloat]] = [:]
        let bucketWidth: CGFloat = 0.025
        for x in resultXs {
            let key = Int((x / bucketWidth).rounded())
            buckets[key, default: []].append(x)
        }

        guard let best = buckets.max(by: { $0.value.count < $1.value.count })?.value, best.count >= 4 else {
            return nil
        }

        let center = best.reduce(0, +) / CGFloat(best.count)
        let halfWidth: CGFloat = 0.032
        return TableColumnBands(
            resultMin: center - halfWidth,
            resultMax: center + halfWidth,
            referenceMin: center + halfWidth + 0.04
        )
    }

    private static func lineHasLabAlias(tokens: [OCRToken]) -> Bool {
        strictAliasCount(in: tokens) > 0
    }

    private static func strictAliasCount(in tokens: [OCRToken]) -> Int {
        var matched = Set<String>()
        for definition in labDefinitions {
            for token in tokens {
                if tokenMatchesAliasStrict(token.text, definition: definition) {
                    matched.insert(definition.code)
                    break
                }
            }
        }
        return matched.count
    }

    private static func rowHasResultInColumn(_ tokens: [OCRToken], bands: TableColumnBands) -> Bool {
        tokens.contains { token in
            guard token.minX >= bands.resultMin, token.minX <= bands.resultMax else { return false }
            return parseNumericToken(token.text) != nil
        }
    }

    /// 解析表格中的一行：先定项目，再取该行「结果列」数值
    private static func parseTableRow(
        _ tokens: [OCRToken],
        columnBands: TableColumnBands?,
        forcedDefinition: LabDefinition? = nil
    ) -> ExtractedLabValue? {
        let combined = tokens.map(\.text).joined(separator: " ")
        if isNonLabTableRow(combined) { return nil }

        if forcedDefinition == nil {
            if isRatioRow(combined) { return nil }
            if strictAliasCount(in: tokens) > 1 { return nil }
        } else if isRatioRow(combined) {
            return nil
        }

        guard let definition = forcedDefinition ?? bestDefinitionForRow(tokens: tokens, combined: combined) else {
            return nil
        }

        let refRange = parseReferenceRange(in: combined) ?? LabReferenceRanges.effectiveRange(for: definition.code).map {
            (low: $0.low, high: $0.high)
        }
        let hasAbnormalFlag = combined.range(of: "[↑↓⬆⬇▲▼]", options: .regularExpression) != nil

        guard let value = extractResultFromRow(
            tokens: tokens,
            definition: definition,
            refRange: refRange,
            columnBands: columnBands
        ) else {
            return nil
        }

        return buildLab(
            value: value,
            definition: definition,
            text: combined,
            refRange: refRange,
            isAbnormal: hasAbnormalFlag
        )
    }

    private static func bestDefinitionForRow(tokens: [OCRToken], combined: String) -> LabDefinition? {
        var best: (LabDefinition, Int)?

        for definition in labDefinitions {
            let score = rowMatchScore(definition: definition, tokens: tokens, combined: combined)
            guard score > 0 else { continue }
            if let current = best {
                if score > current.1 { best = (definition, score) }
            } else {
                best = (definition, score)
            }
        }
        return best?.0
    }

    private static func rowMatchScore(definition: LabDefinition, tokens: [OCRToken], combined: String) -> Int {
        if isRatioRow(combined) { return 0 }

        for token in tokens {
            let t = token.text.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || isArrowMisreadToken(t) { continue }
            if tokenMatchesAliasStrict(t, definition: definition) { return 100 }
        }

        if definition.code == "ALT" {
            guard combined.range(of: #"(?i)\bALT\b|丙氨酸|谷丙"#, options: .regularExpression) != nil else { return 0 }
            if combined.range(of: #"(?i)\bAST\b|天门冬|谷草"#, options: .regularExpression) != nil,
               combined.range(of: #"(?i)\bALT\b"#, options: .regularExpression) == nil { return 0 }
            return 85
        }
        if definition.code == "AST" {
            guard combined.range(of: #"(?i)\bAST\b|天门冬|谷草"#, options: .regularExpression) != nil else { return 0 }
            if combined.range(of: #"(?i)\bALT\b|丙氨酸|谷丙"#, options: .regularExpression) != nil,
               combined.range(of: #"(?i)\bAST\b"#, options: .regularExpression) == nil { return 0 }
            return 85
        }
        if definition.code == "ALB" {
            guard combined.range(of: #"(?i)\bALB\b|\bALOB\b|白蛋白"#, options: .regularExpression) != nil else { return 0 }
            return 80
        }
        if definition.code == "GLOB" {
            guard combined.range(of: #"(?i)\bGLOB\b|\bGLB\b|球蛋白|\[\s*GLB\s*\]"#, options: .regularExpression) != nil,
                  !combined.contains("白球") else { return 0 }
            return 80
        }

        for alias in definition.aliases where alias.count >= 3 {
            if combined.localizedCaseInsensitiveContains(alias) { return 70 }
        }
        return 0
    }

    private static func tokenContainsBracketCode(_ token: String, code: String) -> Bool {
        let upper = token.uppercased()
        if upper.contains("[\(code.uppercased())]") { return true }
        if code == "GLOB", upper.contains("[GLB]") { return true }
        if code == "Urea", upper.contains("[UREA]") { return true }
        if code == "Hb", upper.contains("[HGB]") { return true }
        if code == "ANC", upper.contains("[NEU#]") { return true }
        return false
    }

    private static func tokenMatchesAliasStrict(_ token: String, definition: LabDefinition) -> Bool {
        let t = token.trimmingCharacters(in: .whitespaces)
        if t.isEmpty || t.contains("/") { return false }
        let upper = t.uppercased()

        if upper == definition.code.uppercased() { return true }
        for alias in definition.aliases {
            if upper == alias.uppercased() { return true }
        }
        if definition.code == "Cl", upper == "CL" { return true }
        if definition.code == "Ca", upper == "CA", !t.contains("抗") { return true }
        if definition.code == "AG", upper == "A/G" || t == "A/G" || t.contains("[A/G]") { return true }
        if definition.code == "Cr", upper == "CREA" { return true }
        if definition.code == "Na", upper == "NA" { return true }
        if definition.code == "GLOB", upper == "GLB" { return true }
        if definition.code == "Urea", upper == "UREA" { return true }
        if definition.code == "Hb", upper == "HGB" || tokenContainsBracketCode(t, code: "HGB") { return true }
        if definition.code == "ANC", tokenContainsBracketCode(t, code: "NEU#") { return true }
        if tokenContainsBracketCode(t, code: definition.code) { return true }
        return false
    }

    private static func extractResultFromRow(
        tokens: [OCRToken],
        definition: LabDefinition,
        refRange: (low: Double, high: Double)?,
        columnBands: TableColumnBands?
    ) -> Double? {
        let sorted = tokens
            .sorted { $0.minX < $1.minX }
            .filter { !isArrowMisreadToken($0.text) }
        let combined = sorted.map(\.text).joined(separator: " ")

        if let bands = columnBands,
           let value = pickResultFromColumn(
               sorted: sorted,
               bands: bands,
               definition: definition,
               refRange: refRange,
               combined: combined
           ) {
            return value
        }

        if let aliasIndex = sorted.firstIndex(where: { tokenMatchesAliasStrict($0.text, definition: definition) }) {
            if let value = pickResultValueFromTokens(
                sorted: sorted,
                aliasIndex: aliasIndex,
                definition: definition,
                refRange: refRange
            ) {
                return value
            }

            let after = Array(sorted.suffix(from: aliasIndex + 1))
            for token in after.prefix(4) {
                guard let value = parseNumericToken(token.text) else { continue }
                guard definition.plausibleRange.contains(value),
                      !isReferenceValue(value, refRange: refRange),
                      !isValueInReferenceBand(value, text: combined),
                      !isLikelyRowIndex(value, in: combined),
                      valueMatchesExpectedUnit(value, definition: definition, text: combined) else { continue }
                return value
            }
        }

        let beforeRef = textBeforeReferenceBand(combined)
        return pickResultValue(from: beforeRef, definition: definition, refRange: refRange)
    }

    /// 只取参考区间列之前的片段，避免把 9.0~50.0 里的数字当成结果
    private static func textBeforeReferenceBand(_ text: String) -> String {
        if let range = text.range(of: #"[~～]|[≤<]\s*\d"#, options: .regularExpression) {
            return String(text[..<range.lowerBound])
        }
        return text
    }

    /// 只取落在「结果」列 X 区间内的 token，避免串到参考区间或其它行的数
    private static func pickResultFromColumn(
        sorted: [OCRToken],
        bands: TableColumnBands,
        definition: LabDefinition,
        refRange: (low: Double, high: Double)?,
        combined: String
    ) -> Double? {
        let colTokens = sorted.filter { token in
            token.minX >= bands.resultMin
                && token.minX <= bands.resultMax
                && token.minX < bands.referenceMin
        }

        var decimals: [Double] = []
        var integers: [Double] = []

        for token in colTokens {
            let value: Double?
            if token.text.contains(".") {
                value = parseTokenNumeric(token.text) ?? parseNumericToken(token.text)
            } else {
                value = parseNumericToken(token.text)
            }
            guard let value,
                  definition.plausibleRange.contains(value),
                  !isReferenceValue(value, refRange: refRange),
                  !isValueInReferenceBand(value, text: combined),
                  !isLikelyRowIndex(value, in: combined),
                  valueMatchesExpectedUnit(value, definition: definition, text: combined) else { continue }

            if token.text.contains(".") || value != floor(value) {
                decimals.append(value)
            } else if value >= 10 || definition.code == "AG" || ["GGT", "ALP", "Cr", "UA"].contains(definition.code) {
                integers.append(value)
            } else if value > 0, value < 10, ["AG", "Ca", "Mg", "P", "K"].contains(definition.code) {
                decimals.append(value)
            }
        }

        if let best = bestResultCandidate(from: decimals, definition: definition) { return best }
        return integers.first
    }

    private static func parseNumericToken(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        if let v = Double(t) { return v }
        if let regex = try? NSRegularExpression(pattern: #"^(\d+\.?\d*)$"#),
           let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
           let r = Range(match.range(at: 1), in: t) {
            return Double(t[r])
        }
        return nil
    }

    private static func isNonLabTableRow(_ text: String) -> Bool {
        if text.range(of: #"(?i)项目名称|英文缩写|参考区间|检测方法|序号"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"溶血|黄疸|脂血|检验者|审核者|报告时间|打印时间|采样时间"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"^[\d\s]+$"#, options: .regularExpression) != nil,
           text.range(of: #"[A-Za-z\u4e00-\u9fff]{2,}"#, options: .regularExpression) == nil {
            return true
        }
        return false
    }

    private static func isRatioRow(_ text: String) -> Bool {
        text.range(of: #"(?i)AST/ALT|AST\s*/\s*ALT|谷草/谷丙|谷草\s*/\s*谷丙"#, options: .regularExpression) != nil
    }

    /// 肝功能酶逐项扫描每一行，避免 ALT/AST 合并行互相抢数值
    private static func findLabOnDedicatedLines(
        _ def: LabDefinition,
        tokenLines: [[OCRToken]],
        lineStrings: [String]
    ) -> ExtractedLabValue? {
        for tokens in tokenLines {
            let combined = tokens.map(\.text).joined(separator: " ")
            guard rowContains(def, in: combined) else { continue }
            if let parsed = parseLabRowFromTokens(tokens, definition: def) {
                return parsed
            }
        }
        for line in lineStrings {
            guard rowContains(def, in: line) else { continue }
            if lineHasMultipleLiverEnzymes(line) { continue }
            if let parsed = parseLabRow(line: line, definition: def) {
                return parsed
            }
        }
        return nil
    }

    private static func findLabInFullTextForEnzyme(_ text: String, definition: LabDefinition) -> ExtractedLabValue? {
        guard let aliasPattern = fullTextAliasPattern(for: definition.code) else { return nil }
        let numberPattern = decimalPreferredCodes.contains(definition.code)
            ? #"(\d+\.\d{1,4})"#
            : #"(\d+\.?\d*)"#
        let pattern = "(?i)\(aliasPattern).{0,72}?\(numberPattern)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let value = Double(text[valueRange]) else { continue }
            let snippet = ns.substring(with: match.range)
            let refRange = parseReferenceRange(in: snippet)
            guard definition.plausibleRange.contains(value),
                  !isReferenceValue(value, refRange: refRange),
                  !isValueInReferenceBand(value, text: snippet),
                  !isLikelyRowIndex(value, in: snippet),
                  valueMatchesExpectedUnit(value, definition: definition, text: snippet) else { continue }
            return buildLab(value: value, definition: definition, text: snippet, refRange: refRange, isAbnormal: false)
        }
        return nil
    }

    private static func fullTextAliasPattern(for code: String) -> String? {
        switch code {
        case "ALT": return #"(?:\bALT\b|丙氨酸氨基转移酶|谷丙)"#
        case "AST": return #"(?:\bAST\b|天门冬氨酸氨基转移酶|谷草)"#
        case "ALP": return #"(?:\bALP\b|碱性磷酸酶)"#
        case "GGT": return #"(?:\bGGT\b|γ-谷氨酰|谷氨酰)"#
        case "ALB": return #"(?:\bALB\b|\bALOB\b|白蛋白)"#
        case "GLOB": return #"(?:\bGLOB\b|球蛋白)"#
        case "TP": return #"(?:\bTP\b|总蛋白)"#
        case "TBIL": return #"(?:\bTBIL\b|总胆红素)"#
        case "DBIL": return #"(?:\bDBIL\b|直接胆红素)"#
        case "IBIL": return #"(?:\bIBIL\b|间接胆红素)"#
        case "Na": return #"(?:\bNa\b|钠)"#
        case "K": return #"(?:\bK\b|钾)"#
        case "Cl": return #"(?:\bCl\b|\bCL\b|氯)"#
        case "Ca": return #"(?:\bCa\b|钙)"#
        case "Mg": return #"(?:\bMg\b|镁)"#
        case "P": return #"(?:\bP\b|磷)"#
        case "Urea": return #"(?:\bUrea\b|尿素)"#
        case "Cr": return #"(?:\bCREA\b|\bCr\b|肌酐)"#
        case "UA": return #"(?:\bUA\b|尿酸)"#
        case "CO2": return #"(?:CO2-CP|CO2|二氧化碳)"#
        case "eGFR": return #"(?:eGFR|肾小球滤过)"#
        case "AG": return #"(?:A/G|白球比例)"#
        default: return nil
        }
    }

    private static func lineHasMultipleLiverEnzymes(_ text: String) -> Bool {
        let markers = [#"(?i)\bALT\b"#, #"(?i)\bAST\b"#, #"(?i)\bALP\b"#]
        return markers.filter { text.range(of: $0, options: .regularExpression) != nil }.count > 1
    }

    private static func findLab(
        _ def: LabDefinition,
        tokenLines: [[OCRToken]],
        lineStrings: [String]
    ) -> ExtractedLabValue? {
        for (index, tokens) in tokenLines.enumerated() {
            if let parsed = parseLabRowFromTokens(tokens, definition: def) {
                return parsed
            }
            if rowContains(def, in: tokens.map(\.text).joined(separator: " ")),
               index + 1 < tokenLines.count,
               let parsed = parseLabRowFromTokens(tokenLines[index + 1], definition: def, allowAliasOnlyRow: true) {
                return parsed
            }
        }
        for line in lineStrings {
            if let parsed = parseLabRow(line: line, definition: def) {
                return parsed
            }
        }
        // 多行被 Vision 拆散时，合并相邻 3 行再试（肝功能酶行不合并，避免 ALT/AST 串值）
        if !["ALT", "AST", "ALP"].contains(def.code) {
            for index in lineStrings.indices {
                let end = min(index + 2, lineStrings.count - 1)
                let merged = lineStrings[index...end].joined(separator: " ")
                if lineHasMultipleLiverEnzymes(merged) { continue }
                if let parsed = parseLabRow(line: merged, definition: def) {
                    return parsed
                }
            }
        }
        return nil
    }

    /// 按横向表格列解析：优先取「结果」列中的小数，忽略「提示」列箭头（常被误识为 1）
    private static func parseLabRowFromTokens(
        _ tokens: [OCRToken],
        definition: LabDefinition,
        allowAliasOnlyRow: Bool = false
    ) -> ExtractedLabValue? {
        let sorted = tokens
            .sorted { $0.minX < $1.minX }
            .filter { !isArrowMisreadToken($0.text) }
        let combined = sorted.map(\.text).joined(separator: " ")
        if !allowAliasOnlyRow {
            guard rowContains(definition, in: combined) else { return nil }
        }

        let hasAbnormalFlag = combined.range(of: "[↑↓⬆⬇▲▼]", options: .regularExpression) != nil
        let refRange = parseReferenceRange(in: combined)

        if allowAliasOnlyRow {
            guard let value = pickResultValue(from: combined, definition: definition, refRange: refRange) else {
                return nil
            }
            return buildLab(value: value, definition: definition, text: combined, refRange: refRange, isAbnormal: hasAbnormalFlag)
        }

        if let aliasIndex = sorted.firstIndex(where: { tokenMatchesAlias($0.text, definition: definition) }) {
            if let value = pickResultValueFromTokens(
                sorted: sorted,
                aliasIndex: aliasIndex,
                definition: definition,
                refRange: refRange
            ) {
                return buildLab(value: value, definition: definition, text: combined, refRange: refRange, isAbnormal: hasAbnormalFlag)
            }
            let afterText = sorted.suffix(from: aliasIndex).map(\.text).joined(separator: " ")
            if let value = pickResultValue(from: afterText, definition: definition, refRange: refRange) {
                return buildLab(value: value, definition: definition, text: combined, refRange: refRange, isAbnormal: hasAbnormalFlag)
            }
        }

        return parseLabRow(line: combined, definition: definition)
    }

    private static func parseLabRow(line: String, definition: LabDefinition) -> ExtractedLabValue? {
        let scrubbedLine = scrubMarkerLabelNumbers(line)
        guard rowContains(definition, in: scrubbedLine) else { return nil }
        if ["ALT", "AST", "ALP"].contains(definition.code), lineHasMultipleLiverEnzymes(scrubbedLine) {
            return nil
        }

        let hasAbnormalFlag = scrubbedLine.range(of: "[↑↓⬆⬇▲▼]", options: .regularExpression) != nil
        var cleaned = scrubbedLine.replacingOccurrences(of: arrowPattern, with: " ", options: .regularExpression)
        cleaned = stripTrailingArrowDigits(from: cleaned)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        let refRange = parseReferenceRange(in: cleaned)
        guard let value = pickResultValue(from: cleaned, definition: definition, refRange: refRange) else {
            return nil
        }

        return buildLab(value: value, definition: definition, text: cleaned, refRange: refRange, isAbnormal: hasAbnormalFlag)
    }

    private static func buildLab(
        value: Double,
        definition: LabDefinition,
        text: String,
        refRange: (low: Double, high: Double)?,
        isAbnormal: Bool
    ) -> ExtractedLabValue {
        let resolvedRef = refRange ?? LabReferenceRanges.effectiveRange(for: definition.code)
        let refLow = resolvedRef?.low
        let refHigh = resolvedRef?.high
        let outOfRange = LabReferenceRanges.isOutOfRange(
            value: value,
            low: refLow,
            high: refHigh,
            labType: definition.code
        )
        return ExtractedLabValue(
            labType: definition.code,
            value: value,
            unit: parseUnit(in: text, definition: definition) ?? definition.defaultUnit,
            refRangeLow: refLow,
            refRangeHigh: refHigh,
            isAbnormal: isAbnormal || outOfRange
        )
    }

    private static func rowContains(_ definition: LabDefinition, in text: String) -> Bool {
        if definition.code == "CA199" {
            if text.range(of: "(?i)CA\\s*[-_]?\\s*19\\s*[-_]?\\s*9|糖类抗原\\s*19|CA199", options: .regularExpression) != nil {
                return true
            }
        }
        if definition.code == "CA125" {
            if text.range(of: "(?i)CA\\s*[-_]?\\s*125|糖类抗原\\s*125|CA125", options: .regularExpression) != nil {
                return true
            }
        }
        if definition.code == "ALT" {
            guard !isAlbuminOrTotalProteinLine(text) else { return false }
            return text.range(of: #"(?i)\bALT\b|\[ALT\]|丙氨酸氨基转移酶|谷丙转氨酶|谷丙"#, options: .regularExpression) != nil
        }
        if definition.code == "AST" {
            guard !isAlbuminOrTotalProteinLine(text) else { return false }
            return text.range(of: #"(?i)\bAST\b|\[AST\]|天门冬氨酸氨基转移酶|谷草转氨酶|谷草"#, options: .regularExpression) != nil
        }
        if definition.code == "ALP" {
            return text.range(of: #"(?i)\bALP\b|碱性磷酸酶"#, options: .regularExpression) != nil
        }
        if definition.code == "ALB" {
            let isAlbumin = text.range(of: #"(?i)\bALB\b|\bALOB\b|白蛋白"#, options: .regularExpression) != nil
            let isALT = text.range(of: #"(?i)\bALT\b|丙氨酸|谷丙"#, options: .regularExpression) != nil
            return isAlbumin && !isALT
        }
        if definition.code == "TP" {
            let isTP = text.range(of: #"(?i)总蛋白|\bTP\b"#, options: .regularExpression) != nil
            let isALT = text.range(of: #"(?i)\bALT\b|丙氨酸|谷丙"#, options: .regularExpression) != nil
            return isTP && !isALT
        }
        let upper = text.uppercased()
        return definition.aliases.contains { alias in
            matchesAlias(alias, in: text, upper: upper, definition: definition)
        }
    }

    private static func isAlbuminOrTotalProteinLine(_ text: String) -> Bool {
        text.range(of: #"(?i)总蛋白|白蛋白|ALB(?!T)|\bALOB\b|ALBUMIN|球蛋白"#, options: .regularExpression) != nil
            || text.range(of: #"(?i)(?:^|\s)TP(?:\s|$)"#, options: .regularExpression) != nil
    }

    private static func matchesAlias(
        _ alias: String,
        in text: String,
        upper: String,
        definition: LabDefinition
    ) -> Bool {
        let a = alias.uppercased()
        if shortLabCodes.contains(definition.code) || a.count <= 4 {
            return upper.range(of: #"(?i)\b\#(NSRegularExpression.escapedPattern(for: a))\b"#, options: .regularExpression) != nil
                || text.localizedCaseInsensitiveContains(alias)
        }
        return text.localizedCaseInsensitiveContains(alias) || upper.contains(a)
    }

    private static let shortLabCodes: Set<String> = ["ALT", "AST", "ALP", "ALB", "TP", "CEA", "WBC", "ANC", "Hb", "PLT", "Cr"]

    /// 全文回退：仅匹配带小数点的结果（50.94、753.40），避免 CA19-9 里的 19
    private static func findLabInFullText(_ text: String, definition: LabDefinition) -> ExtractedLabValue? {
        let scrubbed = scrubMarkerLabelNumbers(text)
        let aliasPattern: String
        switch definition.code {
        case "CA199":
            aliasPattern = #"(?:CA199|糖类抗原\s*CA199)"#
        case "CA125":
            aliasPattern = #"(?:CA125|糖类抗原\s*125)"#
        case "CEA":
            aliasPattern = #"(?:CEA|癌胚抗原)"#
        default:
            return nil
        }
        let pattern = "(?i)\(aliasPattern).{0,80}?(\\d+\\.\\d{2,4})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let ns = scrubbed as NSString
        let matches = regex.matches(in: scrubbed, range: NSRange(location: 0, length: ns.length))
        var best: (value: Double, snippet: String, ref: (low: Double, high: Double)?)?

        for match in matches {
            guard let valueRange = Range(match.range(at: 1), in: scrubbed),
                  let value = Double(scrubbed[valueRange]) else { continue }
            let snippet = ns.substring(with: match.range)
            let refRange = parseReferenceRange(in: snippet)
            guard definition.plausibleRange.contains(value),
                  !isReferenceValue(value, refRange: refRange),
                  !isReferenceBandNumber(value, in: snippet) else { continue }

            if let current = best {
                if value > current.value { best = (value, snippet, refRange) }
            } else {
                best = (value, snippet, refRange)
            }
        }

        guard let picked = best else { return nil }
        let hasAbnormalFlag = picked.snippet.range(of: "[↑↓⬆⬇▲▼]", options: .regularExpression) != nil
        return buildLab(
            value: picked.value,
            definition: definition,
            text: picked.snippet,
            refRange: picked.ref,
            isAbnormal: hasAbnormalFlag
        )
    }

    /// 按列取「英文缩写」右侧的结果 token（对应表格「结果」列）
    private static func pickResultValueFromTokens(
        sorted: [OCRToken],
        aliasIndex: Int,
        definition: LabDefinition,
        refRange: (low: Double, high: Double)?
    ) -> Double? {
        let aliasX = sorted[aliasIndex].minX
        let refIndex = sorted.firstIndex { token in
            token.text.contains("~") || token.text.contains("～") || token.text.contains("≤") || token.text.contains("<")
        }
        let rightTokens = sorted.enumerated().compactMap { idx, token -> OCRToken? in
            guard token.minX > aliasX + 0.012 else { return nil }
            if let refIndex, idx >= refIndex { return nil }
            return token
        }
        let rowText = textBeforeReferenceBand(sorted.map(\.text).joined(separator: " "))

        var decimals: [Double] = []
        var integers: [Double] = []
        for token in rightTokens {
            if isArrowMisreadToken(token.text) { continue }
            let value: Double?
            if token.text.contains(".") {
                value = parseTokenNumeric(token.text)
            } else {
                value = parseNumericToken(token.text)
            }
            guard let value,
                  definition.plausibleRange.contains(value),
                  !isReferenceValue(value, refRange: refRange),
                  !isValueInReferenceBand(value, text: rowText),
                  !isReferenceBandNumber(value, in: rowText),
                  !isLikelyRowIndex(value, in: rowText),
                  valueMatchesExpectedUnit(value, definition: definition, text: rowText) else { continue }
            if token.text.contains(".") {
                decimals.append(value)
            } else if value >= 10 || definition.code == "AG" {
                integers.append(value)
            }
        }
        if let best = bestResultCandidate(from: decimals, definition: definition) { return best }
        return integers.first
    }

    private static func parseTokenNumeric(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let regex = try? NSRegularExpression(pattern: #"^(\d+\.\d{1,4})$"#),
              let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              let r = Range(match.range(at: 1), in: t) else { return nil }
        return Double(t[r])
    }

    /// 把 CA19-9 / 糖类抗原19-9 中的数字替换掉，避免当成检验结果
    private static func scrubMarkerLabelNumbers(_ text: String) -> String {
        var s = text
        let patterns = [
            #"(?i)CA\s*[-_]?\s*19\s*[-_]?\s*9"#: "CA199",
            #"糖类抗原\s*19\s*[-_]\s*9"#: "糖类抗原CA199",
            #"(?i)CA\s*[-_]?\s*125"#: "CA125"
        ]
        for (pattern, replacement) in patterns {
            s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return s
    }

  /// ALT/AST 应为 U/L；总蛋白/白蛋白为 g/L，避免把 65 g/L 当成 ALT
    private static func valueMatchesExpectedUnit(
        _ value: Double,
        definition: LabDefinition,
        text: String
    ) -> Bool {
        let hasGL = text.range(of: #"(?i)g/L|g/l|克/升"#, options: .regularExpression) != nil
        let hasUL = text.range(of: #"(?i)U/L|u/l|IU/L|单位/升"#, options: .regularExpression) != nil

        switch definition.code {
        case "ALT", "AST", "ALP", "GGT":
            if hasGL, !hasUL { return false }
            if hasGL, value >= 15, value <= 120 { return false }
            return true
        case "ALB", "TP", "GLOB":
            if hasUL, !hasGL { return false }
            return true
        default:
            return true
        }
    }

    private static func isReferenceBandNumber(_ value: Double, in text: String) -> Bool {
        if value == 0 || value == 4.5 || value == 36 || value == 4.50 || value == 36.00 {
            if text.contains("参考") || text.contains("~") || text.contains("～") || text.contains("≤") {
                return true
            }
        }
        if value == 19 || value == 9 {
            return text.range(of: #"CA199|19[-_ ]?9|抗原\s*19"#, options: .regularExpression) != nil
        }
        return false
    }

    private static func tokenMatchesAlias(_ token: String, definition: LabDefinition) -> Bool {
        let t = token.trimmingCharacters(in: .whitespaces).uppercased()
        if definition.code == "ALT" {
            if t == "ALB" || t == "ALOB" || t == "TP" || t.hasPrefix("ALB") { return false }
            return t == "ALT" || t.contains("谷丙")
        }
        if definition.code == "ALB" {
            return t == "ALB" || t == "ALOB" || t.contains("白蛋白")
        }
        if definition.code == "TP" {
            return t == "TP" || t.contains("总蛋白")
        }
        return definition.aliases.contains { alias in
            let a = alias.uppercased()
            if shortLabCodes.contains(definition.code) {
                return t == a
            }
            return t == a || t.contains(a)
        }
    }

    /// 肿瘤标志物报告：结果多为 xx.xx 小数；不用整数 1（常为 ↑ 误识）
    private static func pickResultValue(
        from text: String,
        definition: LabDefinition,
        refRange: (low: Double, high: Double)?
    ) -> Double? {
        let scrubbed = scrubMarkerLabelNumbers(cleanedNumericText(text))
        let decimals = extractDecimalValues(from: scrubbed)
        if !decimals.isEmpty {
            let candidates = decimals.filter { v in
                definition.plausibleRange.contains(v)
                    && !isReferenceValue(v, refRange: refRange)
                    && !isValueInReferenceBand(v, text: scrubbed)
                    && !isLikelyRowIndex(v, in: scrubbed)
                    && !isReferenceBandNumber(v, in: scrubbed)
                    && valueMatchesExpectedUnit(v, definition: definition, text: scrubbed)
            }
            if let best = bestResultCandidate(from: candidates, definition: definition) {
                return best
            }
        }

        // 肿瘤标志物必须有 decimal（50.94），不接受 19、9 等整数
        if decimalPreferredCodes.contains(definition.code) {
            return nil
        }

        let integers = parseNumericCandidates(from: scrubbed).filter { v in
            definition.plausibleRange.contains(v)
                && !isReferenceValue(v, refRange: refRange)
                && !isValueInReferenceBand(v, text: scrubbed)
                && !isLikelyRowIndex(v, in: scrubbed)
                && valueMatchesExpectedUnit(v, definition: definition, text: scrubbed)
        }
        let safeInts = integers.filter { v in
            v != 1 && v != 0 && (v >= 10 || ["GGT", "ALP", "Cr", "UA", "PLT", "WBC"].contains(definition.code))
        }
        return safeInts.first
    }

    /// 肿瘤标志物取行内最可能的结果值（通常为最大小数），避免误取序号 1、2
    private static func bestResultCandidate(from values: [Double], definition: LabDefinition) -> Double? {
        guard !values.isEmpty else { return nil }
        if decimalPreferredCodes.contains(definition.code) {
            return values.max()
        }
        if ["ALT", "AST", "ALP"].contains(definition.code) {
            return values.first
        }
        return values.first
    }

    private static func isLikelyRowIndex(_ value: Double, in text: String) -> Bool {
        guard value >= 1, value <= 26, value == floor(value) else { return false }
        let idx = String(format: "%.0f", value)
        if text.range(of: #"^\s*\#(idx)(?:\s|$)"#, options: .regularExpression) != nil { return true }
        if text.range(of: #"序号\s*\#(idx)\b"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// 行内所有「参考区间」数字（如 9.0~50.0），避免误当成检验结果
    private static func referenceBandNumbers(in text: String) -> Set<Double> {
        var nums = Set<Double>()
        let scrubbed = scrubPowerUnitsForRef(text)
        if let regex = try? NSRegularExpression(pattern: #"(\d+\.?\d*)\s*[~～\-—]\s*(\d+\.?\d*)"#) {
            let ns = scrubbed as NSString
            for match in regex.matches(in: scrubbed, range: NSRange(location: 0, length: ns.length)) {
                if match.numberOfRanges >= 3,
                   let r1 = Range(match.range(at: 1), in: scrubbed),
                   let r2 = Range(match.range(at: 2), in: scrubbed),
                   let a = Double(scrubbed[r1]),
                   let b = Double(scrubbed[r2]),
                   a <= b {
                    nums.insert(a)
                    nums.insert(b)
                }
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"[≤<]\s*(\d+\.?\d*)"#) {
            let ns = scrubbed as NSString
            for match in regex.matches(in: scrubbed, range: NSRange(location: 0, length: ns.length)) {
                if let r = Range(match.range(at: 1), in: scrubbed), let high = Double(scrubbed[r]) {
                    nums.insert(0)
                    nums.insert(high)
                }
            }
        }
        return nums
    }

    private static func isValueInReferenceBand(_ value: Double, text: String) -> Bool {
        referenceBandNumbers(in: text).contains { abs($0 - value) < 0.011 }
    }

    private static func cleanedNumericText(_ text: String) -> String {
        stripTrailingArrowDigits(from: text)
    }

    /// Vision 常把 ↑ 识成 1；去掉结果小数后紧跟的 1/l/|
    private static func stripTrailingArrowDigits(from text: String) -> String {
        var s = text
        let patterns = [
            #"(\d+\.\d{1,4})\s*[1l|I]{1,4}(?=\s|$)"#,
            #"(\d+\.\d{1,4})[1l|I]{1,3}(?=\s|$)"#
        ]
        for pattern in patterns {
            s = s.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
        }
        return s
    }

    private static func isArrowMisreadToken(_ token: String) -> Bool {
        let t = token.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return true }
        if t.range(of: "^[1l|I丨]+$", options: .regularExpression) != nil { return true }
        if t.range(of: arrowPattern, options: .regularExpression) != nil, t.count <= 3 { return true }
        return false
    }

    private static func extractDecimalValues(from text: String) -> [Double] {
        let pattern = #"(?<![\d.])(\d+\.\d{1,4})(?![\d.])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            Double(ns.substring(with: $0.range(at: 1)))
        }
    }

    private static func isReferenceValue(_ value: Double, refRange: (low: Double, high: Double)?) -> Bool {
        guard let ref = refRange else { return false }
        return abs(value - ref.low) < 0.01 || abs(value - ref.high) < 0.01
    }

    private static func isValueAbnormal(value: Double, refRange: (low: Double, high: Double)?) -> Bool {
        guard let ref = refRange else { return false }
        return value > ref.high || value < ref.low
    }

    private static func parseNumericCandidates(from text: String) -> [Double] {
        let pattern = #"(?<![\d.])(\d+\.\d+|\d+)(?![\d.])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { match -> Double? in
            let s = ns.substring(with: match.range(at: 1))
            return Double(s)
        }
    }

    private static func parseReferenceRange(in text: String) -> (low: Double, high: Double)? {
        let scrubbed = scrubPowerUnitsForRef(text)
        // 带「参考」关键词
        let labeledPatterns = [
            #"参考(?:值|范围|区间)[^0-9]{0,20}(\d+\.?\d*)\s*[-~～]\s*(\d+\.?\d*)"#,
            #"参考(?:值|范围|区间)[^0-9]{0,20}[≤<]\s*(\d+\.?\d*)"#
        ]
        for pattern in labeledPatterns {
            if let range = matchReferenceRange(pattern: pattern, in: scrubbed, lessThanOnly: pattern.contains("≤")) {
                return range
            }
        }

        // 9 ~ 50、137 ~ 147 等（整数或小数）
        if let regex = try? NSRegularExpression(pattern: #"(\d+\.?\d*)\s*[~～\-—]\s*(\d+\.?\d*)"#),
           let match = regex.firstMatch(in: scrubbed, range: NSRange(scrubbed.startIndex..., in: scrubbed)),
           match.numberOfRanges >= 3,
           let r1 = Range(match.range(at: 1), in: scrubbed),
           let r2 = Range(match.range(at: 2), in: scrubbed),
           let low = Double(scrubbed[r1]),
           let high = Double(scrubbed[r2]),
           low <= high,
           high <= 500 {
            return (low, high)
        }

        // 0.00 ~ 4.50 形式（必须含 ~，避免把 CA19-9 当成 9-19）
        if let regex = try? NSRegularExpression(pattern: #"(\d+\.\d{1,4})\s*[~～\-—]\s*(\d+\.\d{1,4})"#),
           let match = regex.firstMatch(in: scrubbed, range: NSRange(scrubbed.startIndex..., in: scrubbed)),
           match.numberOfRanges >= 3,
           let r1 = Range(match.range(at: 1), in: scrubbed),
           let r2 = Range(match.range(at: 2), in: scrubbed),
           let low = Double(scrubbed[r1]),
           let high = Double(scrubbed[r2]),
           low <= high,
           high <= 500 {
            return (low, high)
        }

        // ≤36.00 须靠近「参考」或「区间」
        if scrubbed.localizedCaseInsensitiveContains("参考") || scrubbed.localizedCaseInsensitiveContains("区间") {
            if let regex = try? NSRegularExpression(pattern: #"[≤<]\s*(\d+\.?\d*)"#),
               let match = regex.firstMatch(in: scrubbed, range: NSRange(scrubbed.startIndex..., in: scrubbed)),
               let r = Range(match.range(at: 1), in: scrubbed),
               let high = Double(scrubbed[r]),
               high <= 500 {
                return (0, high)
            }
        }
        return nil
    }

    /// 去掉 10^9/L 等单位中的数字，避免误当成参考区间
    private static func scrubPowerUnitsForRef(_ text: String) -> String {
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

    private static func matchReferenceRange(
        pattern: String,
        in text: String,
        lessThanOnly: Bool
    ) -> (low: Double, high: Double)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        if lessThanOnly {
            guard let r = Range(match.range(at: 1), in: text),
                  let high = Double(text[r]) else { return nil }
            return (0, high)
        }
        guard match.numberOfRanges >= 3,
              let r1 = Range(match.range(at: 1), in: text),
              let r2 = Range(match.range(at: 2), in: text),
              let low = Double(text[r1]),
              let high = Double(text[r2]) else { return nil }
        return (min(low, high), max(low, high))
    }

    private static func parseUnit(in text: String, definition: LabDefinition) -> String? {
        let beforeRef = textBeforeReferenceBand(text)
        let mmolPreferred: Set<String> = ["Na", "K", "Cl", "Ca", "Mg", "P", "Urea", "CO2"]
        let umolPreferred: Set<String> = ["TBIL", "DBIL", "IBIL", "Cr", "UA"]
        let ulPreferred: Set<String> = ["ALT", "AST", "ALP", "GGT"]
        let glPreferred: Set<String> = ["ALB", "TP", "GLOB", "Hb"]

        if mmolPreferred.contains(definition.code) {
            if beforeRef.range(of: #"(?i)mmol\s*/\s*L"#, options: .regularExpression) != nil { return "mmol/L" }
            return definition.defaultUnit
        }
        if umolPreferred.contains(definition.code) {
            if beforeRef.range(of: #"(?i)umol\s*/\s*L|μmol\s*/\s*L"#, options: .regularExpression) != nil {
                return "μmol/L"
            }
            return definition.defaultUnit
        }
        if ulPreferred.contains(definition.code) {
            if beforeRef.range(of: #"(?i)U\s*/\s*L"#, options: .regularExpression) != nil { return "U/L" }
            return definition.defaultUnit
        }
        if glPreferred.contains(definition.code) {
            if beforeRef.range(of: #"(?i)g\s*/\s*L"#, options: .regularExpression) != nil { return "g/L" }
            return definition.defaultUnit
        }

        let units = ["ng/mL", "ng/ml", "μg/L", "ug/L", "mmol/L", "U/L", "g/L", "10^9/L", "×10^9/L", "μmol/L", "umol/L", "mL/min"]
        for u in units {
            if beforeRef.range(of: u, options: .caseInsensitive) != nil {
                return u.replacingOccurrences(of: "ng/ml", with: "ng/mL")
                    .replacingOccurrences(of: "umol/L", with: "μmol/L")
            }
        }
        return definition.defaultUnit.isEmpty ? nil : definition.defaultUnit
    }

    // MARK: - Metadata

    private static func extractReportDate(from text: String) -> Date? {
        let patterns = [
            #"(?:报告时间|报告日期)\s*[:：]?\s*(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})"#,
            #"(?:采集时间|采样时间)\s*[:：]?\s*(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})"#,
            #"(?:报告|检验|采样|接收|审核)日期?\s*[:：]?\s*(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日?"#,
            #"(\d{4})[./\-](\d{1,2})[./\-](\d{1,2})"#,
            #"(\d{4})年(\d{1,2})月(\d{1,2})日"#
        ]

        var candidates: [Date] = []
        let cal = Calendar.current

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = text as NSString
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                guard match.numberOfRanges >= 4,
                      let yR = Range(match.range(at: 1), in: text),
                      let mR = Range(match.range(at: 2), in: text),
                      let dR = Range(match.range(at: 3), in: text),
                      let y = Int(text[yR]),
                      let m = Int(text[mR]),
                      let d = Int(text[dR]) else { continue }
                var comps = DateComponents()
                comps.year = y
                comps.month = m
                comps.day = d
                if let date = cal.date(from: comps) { candidates.append(date) }
            }
        }

        let now = Date()
        let valid = candidates.filter { date in
            guard let years = cal.dateComponents([.year], from: date, to: now).year else { return false }
            return years >= 0 && years <= 10 && date <= now.addingTimeInterval(86400)
        }

        return valid.sorted().last
    }

    private static func inferReportType(from text: String) -> ReportType {
        let t = text.uppercased()
        if t.contains("基因") || t.contains("MSI") || t.contains("RAS") || t.contains("BRAF") || t.contains("突变") {
            return .genetic
        }
        if t.contains("病理") || t.contains("镜检") || t.contains("免疫组化") {
            return .pathology
        }
        if t.contains("CT") || t.contains("MRI") || t.contains("超声") || t.contains("影像") || t.contains("PET") {
            return .imaging
        }
        if t.contains("出院") {
            return .discharge
        }
        if t.contains("医嘱") {
            return .order
        }
        if t.contains("发票") || t.contains("费用") || t.contains("金额") {
            return .invoice
        }
        return .lab
    }

    private static func suggestTitle(type: ReportType, date: Date, labs: [ExtractedLabValue]) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: date)
        if let cea = labs.first(where: { $0.labType == "CEA" }) {
            return "\(type.displayName) · CEA \(String(format: "%.2f", cea.value)) · \(dateStr)"
        }
        if let first = labs.first {
            return "\(type.displayName) · \(first.labType) \(String(format: "%.2f", first.value)) · \(dateStr)"
        }
        return "\(type.displayName) \(dateStr)"
    }
}

// MARK: - UIImage orientation

extension UIImage {
    func normalizedUpOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
