import Foundation

/// 虚拟表格 OCR：逐行扫描（一行 = 一个项目 + 一个结果）
/// 1. 按 Y 分行，按 X 分列
/// 2. 每一行：项目名列定指标 → 结果列取第一个数值 → 校验
/// 3. 报告上有多少数据行，就识别多少项（全覆盖）
enum LabTableGridOCR {

    struct Token {
        let text: String
        let midY: CGFloat
        let minX: CGFloat
        let maxX: CGFloat
    }

    struct ColumnLayout {
        let nameMaxX: CGFloat
        let methodMaxX: CGFloat
        let resultMinX: CGFloat
        let resultMaxX: CGFloat
        let unitMaxX: CGFloat
        let refMinX: CGFloat
    }

    struct GridRow {
        let y: CGFloat
        let tokens: [Token]
        let combined: String
        let nameText: String
        let resultText: String
        let unitText: String
        let refText: String
    }

    struct MetricCandidate {
        let code: String
        let value: Double
        let unit: String
        let refLow: Double?
        let refHigh: Double?
        let rowY: CGFloat
        let rowCombined: String
    }

    // MARK: - Entry: row-first（全覆盖）

    static func extractAllRows(
        from lineGroups: [[Token]],
        definitions: [(code: String, aliases: [String], defaultUnit: String, plausibleRange: ClosedRange<Double>)],
        isHeaderRow: (String) -> Bool,
        isSkippedRow: (String) -> Bool,
        parseNumber: (String) -> Double?,
        parseRefRange: (String) -> (low: Double, high: Double)?,
        matchName: (String, String, [String]) -> Int,
        unitMatches: (String, String, String) -> Bool,
        isRefBandNumber: (Double, String) -> Bool
    ) -> [MetricCandidate] {
        let layout = detectColumns(from: lineGroups) ?? defaultColumnLayout
        let mergedLines = mergeSplitTableRows(lineGroups, layout: layout)
        let rows = buildGridRows(from: mergedLines, layout: layout, isHeaderRow: isHeaderRow, isSkippedRow: isSkippedRow)

        guard !rows.isEmpty else { return [] }

        var accepted: [MetricCandidate] = []
        var seenCodes = Set<String>()

        for row in rows {
            guard let (def, score) = bestDefinition(for: row.nameText, definitions: definitions, matchName: matchName),
                  score >= 70 else { continue }
            guard !seenCodes.contains(def.code) else { continue }

            guard let value = extractValueForRow(
                row: row,
                def: def,
                layout: layout,
                parseNumber: parseNumber,
                isRefBandNumber: isRefBandNumber
            ) else { continue }

            let refRange = parseRefRange(row.refText) ?? parseRefRange(row.combined)
            let unit = detectUnit(from: row, def: def) ?? def.defaultUnit

            guard verify(
                def: def,
                value: value,
                unit: unit,
                row: row,
                refRange: refRange,
                unitMatches: unitMatches,
                isRefBandNumber: isRefBandNumber
            ) else { continue }

            seenCodes.insert(def.code)
            accepted.append(MetricCandidate(
                code: def.code,
                value: value,
                unit: unit,
                refLow: refRange?.low,
                refHigh: refRange?.high,
                rowY: row.y,
                rowCombined: row.combined
            ))
        }

        return accepted
    }

    // MARK: - Row → definition

    private static func bestDefinition(
        for nameText: String,
        definitions: [(code: String, aliases: [String], defaultUnit: String, plausibleRange: ClosedRange<Double>)],
        matchName: (String, String, [String]) -> Int
    ) -> ((code: String, aliases: [String], defaultUnit: String, plausibleRange: ClosedRange<Double>), Int)? {
        var best: ((code: String, aliases: [String], defaultUnit: String, plausibleRange: ClosedRange<Double>), Int)?
        for def in definitions {
            let score = matchName(def.code, nameText, def.aliases)
            guard score > 0 else { continue }
            if let current = best {
                if score > current.1 { best = (def, score) }
            } else {
                best = (def, score)
            }
        }
        return best
    }

    // MARK: - Row → value（只从本行取）

    private static func extractValueForRow(
        row: GridRow,
        def: (code: String, aliases: [String], defaultUnit: String, plausibleRange: ClosedRange<Double>),
        layout: ColumnLayout,
        parseNumber: (String) -> Double?,
        isRefBandNumber: (Double, String) -> Bool
    ) -> Double? {
        // ① 方括号格式最可靠： [ALT] … 31.9 U/L（跳过后面的参考区间 9~50）
        if let bracket = extractAfterBracket(in: row.combined, code: def.code, parseNumber: parseNumber),
           def.plausibleRange.contains(bracket),
           !isRefBandNumber(bracket, row.refText) {
            return bracket
        }

        // ② 结果列：取最靠左的第一个有效数字
        let resultTokens = row.tokens
            .filter { $0.minX >= layout.resultMinX - 0.02 && $0.maxX <= layout.resultMaxX + 0.03 }
            .filter { !isArrowToken($0.text) }
            .sorted { $0.minX < $1.minX }

        for token in resultTokens {
            if let value = parseNumber(cleanNumeric(token.text)),
               def.plausibleRange.contains(value),
               !isRefBandNumber(value, row.refText) {
                return value
            }
        }

        // ③ 别名 token 右侧第一个数字（动态，不依赖固定列宽）
        if let aliasX = rightmostAliasX(in: row, code: def.code, aliases: def.aliases) {
            let afterAlias = row.tokens
                .filter { $0.minX > aliasX + 0.008 && $0.minX < layout.refMinX - 0.02 }
                .filter { !isArrowToken($0.text) }
                .sorted { $0.minX < $1.minX }

            for token in afterAlias {
                if token.text.range(of: #"[\u4e00-\u9fff]{2,}"#, options: .regularExpression) != nil { continue }
                if let value = parseNumber(cleanNumeric(token.text)),
                   def.plausibleRange.contains(value),
                   !isRefBandNumber(value, row.refText),
                   !isRefBandNumber(value, row.combined) {
                    return value
                }
            }
        }

        return nil
    }

    private static func rightmostAliasX(
        in row: GridRow,
        code: String,
        aliases: [String]
    ) -> CGFloat? {
        var maxX: CGFloat?
        for token in row.tokens {
            let t = token.text.uppercased()
            if t.contains("[\(code.uppercased())]") { maxX = max(maxX ?? 0, token.maxX) }
            if code == "GLOB", t.contains("[GLB]") { maxX = max(maxX ?? 0, token.maxX) }
            if code == "Urea", t.contains("[UREA]") { maxX = max(maxX ?? 0, token.maxX) }
            if code == "AG", t.contains("A/G") { maxX = max(maxX ?? 0, token.maxX) }
            if code == "Hb", t.contains("[HGB]") { maxX = max(maxX ?? 0, token.maxX) }
            if code == "ANC", t.contains("[NEU#]") { maxX = max(maxX ?? 0, token.maxX) }
            for alias in aliases where alias.count <= 5 {
                if t == alias.uppercased() { maxX = max(maxX ?? 0, token.maxX) }
            }
        }
        return maxX
    }

    private static func extractAfterBracket(in text: String, code: String, parseNumber: (String) -> Double?) -> Double? {
        let codePattern: String
        switch code {
        case "GLOB": codePattern = #"\[\s*GLB\s*\]|\[\s*GLOB\s*\]"#
        case "Urea": codePattern = #"\[\s*UREA\s*\]"#
        case "AG": codePattern = #"\[\s*A/G\s*\]|\[\s*AG\s*\]"#
        case "Cr": codePattern = #"\[\s*Cr\s*\]|\[\s*CREA\s*\]"#
        case "Hb": codePattern = #"\[\s*HGB\s*\]|\[\s*Hb\s*\]"#
        case "ANC": codePattern = #"\[\s*NEU#\s*\]"#
        case "RBC": codePattern = #"\[\s*RBC\s*\]"#
        case "WBC": codePattern = #"\[\s*WBC\s*\]"#
        case "PLT": codePattern = #"\[\s*PLT\s*\]"#
        default:
            codePattern = #"\[\s*\#(NSRegularExpression.escapedPattern(for: code))\s*\]"#
        }
        // 方括号后、参考区间（~）前的第一个数
        let pattern = "(?i)\(codePattern)(?:(?!~|～)[\\s\\S]){0,120}?(\\d+\\.?\\d*)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return parseNumber(String(text[r]))
    }

    // MARK: - Merge split rows

    /// Vision 常把「项目名」和「结果」拆成上下两行，合并回完整表格行
    private static func mergeSplitTableRows(_ lineGroups: [[Token]], layout: ColumnLayout) -> [[Token]] {
        guard lineGroups.count > 1 else { return lineGroups }
        var merged: [[Token]] = []
        var index = 0

        while index < lineGroups.count {
            let current = lineGroups[index]
            let currentText = current.map(\.text).joined(separator: " ")

            if index + 1 < lineGroups.count,
               rowLooksLikeNameOnly(current, layout: layout),
               rowLooksLikeResultOnly(lineGroups[index + 1], layout: layout) {
                merged.append(current + lineGroups[index + 1])
                index += 2
                continue
            }

            merged.append(current)
            index += 1
        }
        return merged
    }

    private static func rowLooksLikeNameOnly(_ tokens: [Token], layout: ColumnLayout) -> Bool {
        let text = tokens.map(\.text).joined(separator: " ")
        guard text.range(of: #"\[[A-Za-z/]+\]"#, options: .regularExpression) != nil
                || text.range(of: #"[\u4e00-\u9fff]{2,}"#, options: .regularExpression) != nil else {
            return false
        }
        let hasResult = tokens.contains { t in
            t.minX >= layout.resultMinX - 0.02
                && t.text.range(of: #"^\d+\.?\d*$"#, options: .regularExpression) != nil
        }
        return !hasResult
    }

    private static func rowLooksLikeResultOnly(_ tokens: [Token], layout: ColumnLayout) -> Bool {
        let text = tokens.map(\.text).joined(separator: " ")
        guard text.range(of: #"\[[A-Za-z/]+\]"#, options: .regularExpression) == nil else { return false }
        return tokens.contains { t in
            t.minX >= layout.resultMinX - 0.02
                && t.text.range(of: #"^\d+\.?\d*$"#, options: .regularExpression) != nil
        }
    }

    // MARK: - Grid build

    private static func buildGridRows(
        from lineGroups: [[Token]],
        layout: ColumnLayout,
        isHeaderRow: (String) -> Bool,
        isSkippedRow: (String) -> Bool
    ) -> [GridRow] {
        lineGroups.compactMap { tokens -> GridRow? in
            guard !tokens.isEmpty else { return nil }
            let sorted = tokens.sorted { $0.minX < $1.minX }
            let combined = sorted.map(\.text).joined(separator: " ")
            if isHeaderRow(combined) || isSkippedRow(combined) { return nil }
            guard combined.range(of: #"\d"#, options: .regularExpression) != nil else { return nil }

            let y = sorted.map(\.midY).reduce(0, +) / CGFloat(sorted.count)

            // 项目名 = 检测方法列左侧全部（含 [ALT] 等）
            let nameTokens = sorted.filter { $0.minX < layout.methodMaxX }
            let resultTokens = sorted.filter {
                $0.minX >= layout.resultMinX - 0.02 && $0.maxX <= layout.resultMaxX + 0.04
            }
            let unitTokens = sorted.filter {
                $0.minX > layout.resultMaxX - 0.02 && $0.maxX <= layout.unitMaxX + 0.02
            }
            let refTokens = sorted.filter { $0.minX >= layout.refMinX - 0.02 }

            let nameText = nameTokens.map(\.text).joined(separator: " ")
            guard !nameText.isEmpty else { return nil }

            return GridRow(
                y: y,
                tokens: sorted,
                combined: combined,
                nameText: nameText,
                resultText: resultTokens.map(\.text).joined(separator: " "),
                unitText: unitTokens.map(\.text).joined(separator: " "),
                refText: refTokens.isEmpty ? combined : refTokens.map(\.text).joined(separator: " ")
            )
        }
    }

    private static func detectColumns(from lineGroups: [[Token]]) -> ColumnLayout? {
        var resultX: CGFloat?
        var refX: CGFloat?
        var methodX: CGFloat?
        var nameX: CGFloat?

        for tokens in lineGroups {
            for t in tokens {
                if t.text.contains("结果") { resultX = t.minX }
                if t.text.contains("参考") { refX = t.minX }
                if t.text.contains("检测方法") { methodX = t.maxX }
                if t.text.contains("检验项目") || t.text.contains("项目名称") { nameX = t.maxX }
            }
        }

        if let rx = resultX {
            let methodEnd = methodX ?? (rx - 0.08)
            return ColumnLayout(
                nameMaxX: nameX ?? methodEnd,
                methodMaxX: methodEnd,
                resultMinX: rx - 0.03,
                resultMaxX: rx + 0.09,
                unitMaxX: (refX ?? rx + 0.16) - 0.02,
                refMinX: (refX ?? rx + 0.12) - 0.03
            )
        }

        return inferColumnsFromNumericClusters(lineGroups)
    }

    private static func inferColumnsFromNumericClusters(_ lineGroups: [[Token]]) -> ColumnLayout? {
        var xs: [CGFloat] = []
        for tokens in lineGroups {
            for t in tokens where t.text.range(of: #"^\d+\.?\d*$"#, options: .regularExpression) != nil {
                if t.minX > 0.22 && t.minX < 0.75 { xs.append(t.minX) }
            }
        }
        guard xs.count >= 6 else { return nil }

        var buckets: [Int: [CGFloat]] = [:]
        for x in xs { buckets[Int((x / 0.028).rounded()), default: []].append(x) }
        guard let cluster = buckets.max(by: { $0.value.count < $1.value.count })?.value else { return nil }
        let center = cluster.reduce(0, +) / CGFloat(cluster.count)

        return ColumnLayout(
            nameMaxX: center - 0.12,
            methodMaxX: center - 0.06,
            resultMinX: center - 0.05,
            resultMaxX: center + 0.05,
            unitMaxX: center + 0.13,
            refMinX: center + 0.09
        )
    }

    private static var defaultColumnLayout: ColumnLayout {
        ColumnLayout(
            nameMaxX: 0.34,
            methodMaxX: 0.50,
            resultMinX: 0.50,
            resultMaxX: 0.60,
            unitMaxX: 0.68,
            refMinX: 0.64
        )
    }

    private static func detectUnit(
        from row: GridRow,
        def: (code: String, aliases: [String], defaultUnit: String, plausibleRange: ClosedRange<Double>)
    ) -> String? {
        let u = row.unitText.lowercased()
        if u.contains("u/l") || u.contains("iu/l") { return "U/L" }
        if u.contains("g/l") { return "g/L" }
        if u.contains("mmol") { return "mmol/L" }
        if u.contains("umol") || u.contains("μmol") { return "μmol/L" }
        if u.contains("ng/ml") { return "ng/mL" }
        if u.contains("mg/l") { return "mg/L" }
        if u.contains("10^9") || u.contains("wbcunit") { return "10^9/L" }
        if u.contains("10^12") || u.contains("rbcunit") { return "10^12/L" }
        if u == "%" || u.contains("％") { return "%" }
        if u == "fl" { return "fL" }
        if u == "pg" { return "pg" }
        return def.defaultUnit.isEmpty ? nil : def.defaultUnit
    }

    private static func verify(
        def: (code: String, aliases: [String], defaultUnit: String, plausibleRange: ClosedRange<Double>),
        value: Double,
        unit: String,
        row: GridRow,
        refRange: (low: Double, high: Double)?,
        unitMatches: (String, String, String) -> Bool,
        isRefBandNumber: (Double, String) -> Bool
    ) -> Bool {
        guard def.plausibleRange.contains(value) else { return false }
        guard !isRefBandNumber(value, row.refText) else { return false }
        guard unitMatches(def.code, unit, row.combined) else { return false }

        if let ref = refRange {
            if abs(value - ref.low) < 0.015 || abs(value - ref.high) < 0.015 { return false }
        }

        switch def.code {
        case "ALT", "AST", "ALP", "GGT":
            if row.nameText.range(of: #"(?i)胆红素|蛋白|白球|TBIL|DBIL"#, options: .regularExpression) != nil { return false }
        case "ALB", "TP", "GLOB":
            if row.nameText.range(of: #"(?i)\[ALT\]|\[AST\]|丙氨酸|天门冬"#, options: .regularExpression) != nil { return false }
        case "Hb":
            if row.nameText.range(of: #"血红蛋白|\[HGB\]|\[Hb\]"#, options: .regularExpression) == nil { return false }
        default: break
        }

        return true
    }

    private static func isArrowToken(_ text: String) -> Bool {
        text.range(of: #"^[↑↓⬆⬇▲▼1l|I丨]+$"#, options: .regularExpression) != nil
    }

    private static func cleanNumeric(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "↑", with: "")
            .replacingOccurrences(of: "↓", with: "")
    }
}
