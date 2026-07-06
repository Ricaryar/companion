import Foundation

struct EditableLabDraft: Identifiable, Equatable {
    let id = UUID()
    var labType: String
    var value: String
    var unit: String
    var refRangeLow: String
    var refRangeHigh: String
    var isSelected: Bool = true

    var displayLabel: String {
        LabTrendCatalog.displayName(for: labType)
    }

    init(
        labType: String,
        value: String,
        unit: String,
        refRangeLow: String = "",
        refRangeHigh: String = "",
        isSelected: Bool = true
    ) {
        self.labType = labType
        self.value = value
        self.unit = unit
        self.refRangeLow = refRangeLow
        self.refRangeHigh = refRangeHigh
        self.isSelected = isSelected
    }

    init(from extracted: ExtractedLabValue) {
        labType = extracted.labType
        value = String(format: "%.2f", extracted.value)
        unit = extracted.unit
        refRangeLow = extracted.refRangeLow.map { String(format: "%.2f", $0) } ?? ""
        refRangeHigh = extracted.refRangeHigh.map { String(format: "%.2f", $0) } ?? ""
    }

    func toExtracted() -> ExtractedLabValue? {
        guard let numeric = Double(value.trimmingCharacters(in: .whitespaces)) else { return nil }
        return ExtractedLabValue(
            labType: labType,
            value: numeric,
            unit: unit,
            refRangeLow: Double(refRangeLow.trimmingCharacters(in: .whitespaces)),
            refRangeHigh: Double(refRangeHigh.trimmingCharacters(in: .whitespaces)),
            isAbnormal: false
        )
    }
}
