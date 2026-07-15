import Foundation

/// 健康豆余额与每日/每周任务进度（本地 UserDefaults）。
@Observable
final class HealthBeansStore {
    static let shared = HealthBeansStore()

    static let checkInReward = 10
    static let monthCardCheckInReward = 20
    static let weekCheckInTarget = 7
    static let weekBonusAt5Days = 10
    static let weekBonusAt7Days = 10
    static let weekBonusThreshold5 = 5
    static let weekBonusThreshold7 = 7

    static let adReward = 10
    static let adDailyLimit = 5
    static let shareReward = 15
    static let quizRewardPerCorrect = 5
    static let quizDailyLimit = 3

    /// 充值比例：1 元 = 10 健康豆
    static let rechargeBeansPerYuan = 10
    /// 月卡权益：本月提问积分八折
    static let monthCardQuestionDiscount = 0.8
    static let monthCardPriceYuan = 9.9
    static let monthCardFollowUpCards = 3

    private let defaults = UserDefaults.standard
    private(set) var changeToken = 0

    private enum Key {
        static let balance = "healthBeans.balance"
        static let dayKey = "healthBeans.dayKey"
        static let checkedIn = "healthBeans.checkedIn"
        static let adsWatched = "healthBeans.adsWatched"
        static let shared = "healthBeans.shared"
        static let quizCorrect = "healthBeans.quizCorrect"
        static let weekKey = "healthBeans.weekKey"
        static let weekCheckInDates = "healthBeans.weekCheckInDates"
        static let weekBonus5Claimed = "healthBeans.weekBonus5Claimed"
        static let weekBonus7Claimed = "healthBeans.weekBonus7Claimed"
        static let rechargeMonthKey = "healthBeans.rechargeMonthKey"
        /// 本月已领取过分档首充赠送的套餐 id（如 "120"、"300"），互不影响
        static let firstBonusClaimedPackageIds = "healthBeans.firstBonusClaimedPackageIds"
        static let monthCardMonthKey = "healthBeans.monthCardMonthKey"
        static let followUpCards = "healthBeans.followUpCards"
    }

    private init() {
        rollDayIfNeeded()
        rollWeekIfNeeded()
        rollMonthIfNeeded()
    }

    private func bump() {
        changeToken += 1
    }

    private var todayKey: String {
        Self.dayKey(for: .now)
    }

    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// 自然周标识（周一为一周起始）。
    private var currentWeekKey: String {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return String(format: "%d-W%02d", comps.yearForWeekOfYear ?? 0, comps.weekOfYear ?? 0)
    }

    private var currentMonthKey: String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: .now)
    }

    /// 跨日自动重置每日进度。
    func rollDayIfNeeded() {
        let today = todayKey
        let stored = defaults.string(forKey: Key.dayKey)
        if stored != today {
            defaults.set(today, forKey: Key.dayKey)
            defaults.set(false, forKey: Key.checkedIn)
            defaults.set(0, forKey: Key.adsWatched)
            defaults.set(false, forKey: Key.shared)
            defaults.set(0, forKey: Key.quizCorrect)
            bump()
        }
    }

    /// 跨周重置签到进度与周奖励领取状态。
    func rollWeekIfNeeded() {
        let week = currentWeekKey
        let stored = defaults.string(forKey: Key.weekKey)
        if stored != week {
            defaults.set(week, forKey: Key.weekKey)
            defaults.set([], forKey: Key.weekCheckInDates)
            defaults.set(false, forKey: Key.weekBonus5Claimed)
            defaults.set(false, forKey: Key.weekBonus7Claimed)
            bump()
        }
    }

    /// 跨月重置各价位「首充分档」标记；月卡随自然月到期。
    func rollMonthIfNeeded() {
        let month = currentMonthKey
        let stored = defaults.string(forKey: Key.rechargeMonthKey)
        if stored != month {
            defaults.set(month, forKey: Key.rechargeMonthKey)
            defaults.set([], forKey: Key.firstBonusClaimedPackageIds)
            bump()
        }
        // 月卡只在购买当月有效
        if let cardMonth = defaults.string(forKey: Key.monthCardMonthKey), cardMonth != month {
            defaults.removeObject(forKey: Key.monthCardMonthKey)
            bump()
        }
    }

    /// 当前签到基础奖励（持有月卡时为 20）。
    var effectiveCheckInReward: Int {
        _ = changeToken
        rollMonthIfNeeded()
        return hasActiveMonthCard ? Self.monthCardCheckInReward : Self.checkInReward
    }

    var hasActiveMonthCard: Bool {
        _ = changeToken
        rollMonthIfNeeded()
        return defaults.string(forKey: Key.monthCardMonthKey) == currentMonthKey
    }

    /// 持有月卡时提问积分为八折。
    var questionCostMultiplier: Double {
        hasActiveMonthCard ? Self.monthCardQuestionDiscount : 1.0
    }

    var followUpCards: Int {
        get {
            _ = changeToken
            return max(0, defaults.integer(forKey: Key.followUpCards))
        }
        set {
            defaults.set(max(0, newValue), forKey: Key.followUpCards)
            bump()
        }
    }

    func hasClaimedFirstBonus(forPackageId id: String) -> Bool {
        _ = changeToken
        rollMonthIfNeeded()
        return firstBonusClaimedPackageIds.contains(id)
    }

    private var firstBonusClaimedPackageIds: Set<String> {
        get {
            Set(defaults.stringArray(forKey: Key.firstBonusClaimedPackageIds) ?? [])
        }
        set {
            defaults.set(Array(newValue).sorted(), forKey: Key.firstBonusClaimedPackageIds)
            bump()
        }
    }

    var balance: Int {
        get {
            _ = changeToken
            rollDayIfNeeded()
            return defaults.integer(forKey: Key.balance)
        }
        set {
            defaults.set(max(0, newValue), forKey: Key.balance)
            bump()
        }
    }

    var hasCheckedInToday: Bool {
        get {
            _ = changeToken
            rollDayIfNeeded()
            return defaults.bool(forKey: Key.checkedIn)
        }
        set {
            defaults.set(newValue, forKey: Key.checkedIn)
            bump()
        }
    }

    private var weekCheckInDates: Set<String> {
        get {
            Set(defaults.stringArray(forKey: Key.weekCheckInDates) ?? [])
        }
        set {
            defaults.set(Array(newValue).sorted(), forKey: Key.weekCheckInDates)
            bump()
        }
    }

    /// 本周已签到天数（0…7）。
    var weekCheckInCount: Int {
        _ = changeToken
        rollWeekIfNeeded()
        return weekCheckInDates.count
    }

    var hasClaimedWeekBonus5: Bool {
        _ = changeToken
        rollWeekIfNeeded()
        return defaults.bool(forKey: Key.weekBonus5Claimed)
    }

    var hasClaimedWeekBonus7: Bool {
        _ = changeToken
        rollWeekIfNeeded()
        return defaults.bool(forKey: Key.weekBonus7Claimed)
    }

    /// 本周 7 天中，按周一→周日是否已签到。
    var weekCheckInFlags: [Bool] {
        _ = changeToken
        rollWeekIfNeeded()
        var cal = Calendar.current
        cal.firstWeekday = 2
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) else {
            return Array(repeating: false, count: 7)
        }
        let dates = weekCheckInDates
        return (0..<7).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { return false }
            return dates.contains(Self.dayKey(for: day))
        }
    }

    var adsWatchedToday: Int {
        get {
            _ = changeToken
            rollDayIfNeeded()
            return defaults.integer(forKey: Key.adsWatched)
        }
        set {
            defaults.set(newValue, forKey: Key.adsWatched)
            bump()
        }
    }

    var hasSharedToday: Bool {
        get {
            _ = changeToken
            rollDayIfNeeded()
            return defaults.bool(forKey: Key.shared)
        }
        set {
            defaults.set(newValue, forKey: Key.shared)
            bump()
        }
    }

    var quizCorrectToday: Int {
        get {
            _ = changeToken
            rollDayIfNeeded()
            return defaults.integer(forKey: Key.quizCorrect)
        }
        set {
            defaults.set(newValue, forKey: Key.quizCorrect)
            bump()
        }
    }

    var adsRemainingToday: Int {
        max(0, Self.adDailyLimit - adsWatchedToday)
    }

    var quizRemainingToday: Int {
        max(0, Self.quizDailyLimit - quizCorrectToday)
    }

    /// 若今日已签到但周进度未计入（兼容升级前旧数据），补记一天。
    func syncTodayCheckInIntoWeekIfNeeded() {
        rollDayIfNeeded()
        rollWeekIfNeeded()
        guard hasCheckedInToday else { return }
        var dates = weekCheckInDates
        guard !dates.contains(todayKey) else { return }
        dates.insert(todayKey)
        weekCheckInDates = dates
    }

    struct CheckInResult {
        let baseReward: Int
        let weekBonus: Int
        var total: Int { baseReward + weekBonus }
        let weekCount: Int
    }

    @discardableResult
    func claimDailyCheckIn() -> CheckInResult? {
        rollDayIfNeeded()
        rollWeekIfNeeded()
        guard !hasCheckedInToday else { return nil }

        hasCheckedInToday = true
        var dates = weekCheckInDates
        dates.insert(todayKey)
        weekCheckInDates = dates

        let baseReward = effectiveCheckInReward
        balance += baseReward

        var weekBonus = 0
        let count = dates.count

        if count >= Self.weekBonusThreshold5, !defaults.bool(forKey: Key.weekBonus5Claimed) {
            defaults.set(true, forKey: Key.weekBonus5Claimed)
            weekBonus += Self.weekBonusAt5Days
            balance += Self.weekBonusAt5Days
        }
        if count >= Self.weekBonusThreshold7, !defaults.bool(forKey: Key.weekBonus7Claimed) {
            defaults.set(true, forKey: Key.weekBonus7Claimed)
            weekBonus += Self.weekBonusAt7Days
            balance += Self.weekBonusAt7Days
        }

        bump()
        return CheckInResult(baseReward: baseReward, weekBonus: weekBonus, weekCount: count)
    }

    /// 预留广告奖励；当前没有广告源时不应调用。
    @discardableResult
    func claimAdReward() -> Int? {
        rollDayIfNeeded()
        guard adsWatchedToday < Self.adDailyLimit else { return nil }
        adsWatchedToday += 1
        balance += Self.adReward
        return Self.adReward
    }

    @discardableResult
    func claimShareReward() -> Int? {
        rollDayIfNeeded()
        guard !hasSharedToday else { return nil }
        hasSharedToday = true
        balance += Self.shareReward
        return Self.shareReward
    }

    @discardableResult
    func claimQuizCorrect() -> Int? {
        rollDayIfNeeded()
        guard quizCorrectToday < Self.quizDailyLimit else { return nil }
        quizCorrectToday += 1
        balance += Self.quizRewardPerCorrect
        return Self.quizRewardPerCorrect
    }

    struct RechargeResult {
        let beans: Int
        let bonus: Int
        let priceYuan: Int
        let followUpCards: Int
        var totalBeans: Int { beans + bonus }
        let isFirstForPackage: Bool
    }

    /// 完成一笔充值到账（正式版可改为 StoreKit 支付成功回调）。
    /// 120 / 300 首充赠送按价位分别计算，互不影响。
    @discardableResult
    func completeRecharge(package: HealthBeanRechargePackage) -> RechargeResult {
        rollMonthIfNeeded()
        let isFirst = package.firstPurchaseBonus > 0 && !hasClaimedFirstBonus(forPackageId: package.id)
        let bonus = isFirst ? package.firstPurchaseBonus : 0
        let total = package.beans + bonus
        balance += total
        if isFirst {
            var claimed = firstBonusClaimedPackageIds
            claimed.insert(package.id)
            firstBonusClaimedPackageIds = claimed
        }
        if package.followUpCards > 0 {
            followUpCards += package.followUpCards
        }
        return RechargeResult(
            beans: package.beans,
            bonus: bonus,
            priceYuan: package.priceYuan,
            followUpCards: package.followUpCards,
            isFirstForPackage: isFirst
        )
    }

    struct MonthCardPurchaseResult {
        let followUpCards: Int
        let alreadyActive: Bool
    }

    /// 购买超值月卡（本自然月有效）。
    @discardableResult
    func purchaseMonthCard() -> MonthCardPurchaseResult {
        rollMonthIfNeeded()
        if hasActiveMonthCard {
            return MonthCardPurchaseResult(followUpCards: 0, alreadyActive: true)
        }
        defaults.set(currentMonthKey, forKey: Key.monthCardMonthKey)
        followUpCards += Self.monthCardFollowUpCards
        bump()
        return MonthCardPurchaseResult(followUpCards: Self.monthCardFollowUpCards, alreadyActive: false)
    }
}

struct HealthBeanRechargePackage: Identifiable, Equatable {
    let id: String
    let beans: Int
    let priceYuan: Int
    /// 该价位本月首次购买时的赠送豆数（与其他价位互不影响）
    let firstPurchaseBonus: Int
    let badge: String?
    /// 套餐说明小字
    let subtitle: String?
    /// 购买后赠送的免费追问卡张数
    let followUpCards: Int

    static let all: [HealthBeanRechargePackage] = [
        HealthBeanRechargePackage(
            id: "60",
            beans: 60,
            priceYuan: 6,
            firstPurchaseBonus: 0,
            badge: nil,
            subtitle: "可追问2次",
            followUpCards: 2
        ),
        HealthBeanRechargePackage(
            id: "120",
            beans: 120,
            priceYuan: 12,
            firstPurchaseBonus: 30,
            badge: "首充送30",
            subtitle: nil,
            followUpCards: 0
        ),
        HealthBeanRechargePackage(
            id: "300",
            beans: 300,
            priceYuan: 30,
            firstPurchaseBonus: 90,
            badge: "首充送90",
            subtitle: nil,
            followUpCards: 0
        ),
    ]
}
