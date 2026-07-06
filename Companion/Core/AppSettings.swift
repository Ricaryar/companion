import Foundation

enum CheckInTimePreference: String, CaseIterable {
    case morning
    case evening

    var defaultHour: Int {
        switch self {
        case .morning: 9
        case .evening: 20
        }
    }

    var defaultMinute: Int {
        switch self {
        case .morning: 0
        case .evening: 30
        }
    }

    var label: String {
        switch self {
        case .morning: CopyStrings.onboardingCheckInMorning
        case .evening: CopyStrings.onboardingCheckInEvening
        }
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    /// 触发 @Observable 刷新（UserDefaults 写入本身不会通知 SwiftUI）
    private(set) var settingsChangeToken = 0

    private func bumpSettingsChange() {
        settingsChangeToken += 1
    }

    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let checkInPreference = "checkInPreference"
        static let mergeReminders = "mergeReminders"
        static let showBristolGuide = "showBristolGuide"
        static let ostomyCalibrationEnabled = "ostomyCalibrationEnabled"
        static let alignLabsToCycle = "alignLabsToCycle"
        static let trackedLabMetricCodes = "trackedLabMetricCodes"
        static let visibleLabMetricCodes = "visibleLabMetricCodes"
        static let customLabReferenceRanges = "customLabReferenceRanges"
        static let oralMorningHour = "oralMorningHour"
        static let oralMorningMinute = "oralMorningMinute"
        static let oralEveningHour = "oralEveningHour"
        static let oralEveningMinute = "oralEveningMinute"
    }

    var hasCompletedOnboarding: Bool {
        get {
            _ = settingsChangeToken
            return defaults.bool(forKey: Key.hasCompletedOnboarding)
        }
        set {
            defaults.set(newValue, forKey: Key.hasCompletedOnboarding)
            bumpSettingsChange()
        }
    }

    var checkInPreference: CheckInTimePreference {
        get {
            _ = settingsChangeToken
            return CheckInTimePreference(rawValue: defaults.string(forKey: Key.checkInPreference) ?? "") ?? .morning
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.checkInPreference)
            bumpSettingsChange()
        }
    }

    var mergeReminders: Bool {
        get { defaults.object(forKey: Key.mergeReminders) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.mergeReminders) }
    }

    var showBristolGuide: Bool {
        get { defaults.object(forKey: Key.showBristolGuide) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showBristolGuide) }
    }

    var ostomyCalibrationEnabled: Bool {
        get { defaults.bool(forKey: Key.ostomyCalibrationEnabled) }
        set { defaults.set(newValue, forKey: Key.ostomyCalibrationEnabled) }
    }

    var alignLabsToCycle: Bool {
        get { defaults.object(forKey: Key.alignLabsToCycle) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.alignLabsToCycle) }
    }

    /// 用户在趋势页勾选的检验项目（如 CEA、CA199、白细胞）
    var trackedLabMetricCodes: [String] {
        get {
            _ = settingsChangeToken
            if let saved = defaults.stringArray(forKey: Key.trackedLabMetricCodes), !saved.isEmpty {
                return saved
            }
            return LabTrendCatalog.defaultTrackedCodes
        }
        set {
            defaults.set(newValue, forKey: Key.trackedLabMetricCodes)
            bumpSettingsChange()
        }
    }

    func isTrackingLabMetric(_ code: String) -> Bool {
        trackedLabMetricCodes.contains(code)
    }

    func toggleLabMetric(_ code: String) {
        var codes = trackedLabMetricCodes
        if let index = codes.firstIndex(of: code) {
            if codes.count > 1 {
                codes.remove(at: index)
                removeVisibleLabMetric(code)
            }
        } else {
            codes.append(code)
            addVisibleLabMetric(code)
        }
        trackedLabMetricCodes = codes
    }

    /// 趋势页当前勾选展示的项目（可多选，须为 tracked 的子集）
    var visibleLabMetricCodes: [String] {
        get {
            _ = settingsChangeToken
            let tracked = trackedLabMetricCodes
            if let saved = defaults.stringArray(forKey: Key.visibleLabMetricCodes), !saved.isEmpty {
                let filtered = saved.filter { tracked.contains($0) }
                if !filtered.isEmpty { return filtered }
            }
            return tracked
        }
        set {
            defaults.set(newValue, forKey: Key.visibleLabMetricCodes)
            bumpSettingsChange()
        }
    }

    func isVisibleLabMetric(_ code: String) -> Bool {
        visibleLabMetricCodes.contains(code)
    }

    func toggleVisibleLabMetric(_ code: String) {
        guard trackedLabMetricCodes.contains(code) else { return }
        var codes = visibleLabMetricCodes
        if let index = codes.firstIndex(of: code) {
            if codes.count > 1 { codes.remove(at: index) }
        } else {
            codes.append(code)
        }
        visibleLabMetricCodes = codes
    }

    func selectAllVisibleLabMetrics() {
        visibleLabMetricCodes = trackedLabMetricCodes
    }

    private func addVisibleLabMetric(_ code: String) {
        var codes = visibleLabMetricCodes
        if !codes.contains(code) { codes.append(code) }
        visibleLabMetricCodes = codes
    }

    private func removeVisibleLabMetric(_ code: String) {
        var codes = visibleLabMetricCodes
        codes.removeAll { $0 == code }
        if codes.isEmpty, let first = trackedLabMetricCodes.first {
            codes = [first]
        }
        visibleLabMetricCodes = codes
    }

    /// 用户自定义参考区间（覆盖内置默认）
    var customLabReferenceRanges: [String: LabReferenceRangeValue] {
        get {
            guard let data = defaults.data(forKey: Key.customLabReferenceRanges),
                  let decoded = try? JSONDecoder().decode([String: LabReferenceRangeValue].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.customLabReferenceRanges)
            }
        }
    }

    func customReferenceRange(for code: String) -> LabReferenceRangeValue? {
        customLabReferenceRanges[LabTypeNormalizer.code(for: code)]
    }

    func setCustomReferenceRange(for code: String, low: Double, high: Double) {
        var map = customLabReferenceRanges
        map[LabTypeNormalizer.code(for: code)] = LabReferenceRangeValue(low: low, high: high)
        customLabReferenceRanges = map
    }

    func resetCustomReferenceRange(for code: String) {
        var map = customLabReferenceRanges
        map.removeValue(forKey: LabTypeNormalizer.code(for: code))
        customLabReferenceRanges = map
    }

    var oralMorningTime: (hour: Int, minute: Int) {
        get {
            (
                defaults.object(forKey: Key.oralMorningHour) as? Int ?? 8,
                defaults.object(forKey: Key.oralMorningMinute) as? Int ?? 0
            )
        }
        set {
            defaults.set(newValue.hour, forKey: Key.oralMorningHour)
            defaults.set(newValue.minute, forKey: Key.oralMorningMinute)
        }
    }

    var oralEveningTime: (hour: Int, minute: Int) {
        get {
            (
                defaults.object(forKey: Key.oralEveningHour) as? Int ?? 20,
                defaults.object(forKey: Key.oralEveningMinute) as? Int ?? 0
            )
        }
        set {
            defaults.set(newValue.hour, forKey: Key.oralEveningHour)
            defaults.set(newValue.minute, forKey: Key.oralEveningMinute)
        }
    }
}
