import Foundation

/// 真实用药 · 疾病大类
enum MedicationDiseaseCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case oncology = "肿瘤/癌症"
    case cardio = "心脑血管"
    case endocrine = "内分泌/代谢"
    case digestive = "消化系统"
    case respiratory = "呼吸系统"
    case neuroPsych = "神经/精神"
    case rheumatology = "风湿免疫"
    case renal = "肾脏/泌尿"
    case hematology = "血液系统"
    case dermSensory = "皮肤/五官"
    case infection = "感染/传染"
    case rareOther = "其他/罕见病"

    var id: String { rawValue }

    var audienceHint: String {
        switch self {
        case .oncology: "肿瘤患者"
        case .cardio: "心脑血管患者"
        case .endocrine: "代谢病患者"
        case .digestive: "消化系统患者"
        case .respiratory: "呼吸系统患者"
        case .neuroPsych: "神经/精神疾病患者"
        case .rheumatology: "自身免疫病患者"
        case .renal: "肾脏/泌尿系统患者"
        case .hematology: "血液病患者"
        case .dermSensory: "皮肤/五官患者"
        case .infection: "感染性疾病患者"
        case .rareOther: "其他患者"
        }
    }

    var subtypes: [String] {
        switch self {
        case .oncology:
            [
                "非小细胞肺癌", "小细胞肺癌", "乳腺癌", "结直肠癌", "胃癌", "肝癌",
                "食管癌", "白血病", "淋巴瘤", "甲状腺癌", "前列腺癌", "卵巢癌",
                "胰腺癌", "肾癌", "膀胱癌", "鼻咽癌", "骨肉瘤", "黑色素瘤", "其他肿瘤",
            ]
        case .cardio:
            ["高血压", "冠心病", "心力衰竭", "心律失常", "脑卒中（中风）后", "动脉硬化", "其他"]
        case .endocrine:
            ["糖尿病（1型）", "糖尿病（2型）", "甲状腺疾病（甲亢）", "甲状腺疾病（甲减）", "痛风", "高血脂", "骨质疏松", "其他"]
        case .digestive:
            ["慢性胃炎", "胃溃疡", "肝炎（乙肝）", "肝炎（丙肝）", "肝硬化", "炎症性肠病（克罗恩）", "炎症性肠病（溃疡性结肠炎）", "胰腺炎", "其他"]
        case .respiratory:
            ["哮喘", "慢阻肺（COPD）", "肺纤维化", "支气管扩张", "其他"]
        case .neuroPsych:
            ["癫痫", "帕金森", "阿尔茨海默", "多发性硬化", "抑郁症", "焦虑症", "双相情感障碍", "精神分裂症", "其他"]
        case .rheumatology:
            ["类风湿关节炎", "强直性脊柱炎", "红斑狼疮", "干燥综合征", "银屑病关节炎", "其他"]
        case .renal:
            ["慢性肾病", "肾衰竭（透析）", "肾病综合征", "尿路感染", "前列腺疾病", "其他"]
        case .hematology:
            ["贫血（缺铁）", "贫血（溶血）", "贫血（再生障碍性）", "血友病", "骨髓增生异常综合征", "其他"]
        case .dermSensory:
            ["银屑病（牛皮癣）", "白癜风", "严重湿疹", "青光眼", "黄斑变性", "其他"]
        case .infection:
            ["HIV/AIDS", "结核病", "病毒性肝炎", "带状疱疹", "其他"]
        case .rareOther:
            ["罕见病", "未归类疾病", "其他"]
        }
    }
}

/// 用药类型（第三级分类）
enum MedicationTherapyKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case targeted = "靶向药"
    case immuno = "免疫治疗药物"
    case rareDisease = "罕见病用药"
    case newOrTrial = "新药/临床试验药物"
    case severeRx = "重症长期处方药"
    case chemo = "化疗药物"
    case commonOTC = "常见非处方药/常见药"
    case other = "其他用药"

    var id: String { rawValue }

    /// 是否纳入现金激励
    var isCashIncentiveEligible: Bool {
        switch self {
        case .targeted, .immuno, .rareDisease, .newOrTrial, .severeRx:
            return true
        case .chemo, .commonOTC, .other:
            return false
        }
    }

    var treatmentLines: [String] {
        switch self {
        case .commonOTC:
            return ["对症治疗", "日常用药", "其他"]
        default:
            return ["一线治疗", "二线治疗", "三线及以上", "辅助/新辅助", "维持治疗", "其他"]
        }
    }
}

enum MedicationShareStatus: String, Codable, Equatable {
    case pending
    case approved
    case rejected
}

enum MedicationSharePlacement: String, Codable, Equatable {
    /// 仅真实用药社区（高价值等）
    case community
    /// 仅科普积分任务区
    case scienceTask
    /// 普通价值：同时投放社区与科普任务
    case both

    var showsInCommunity: Bool {
        self == .community || self == .both
    }

    var showsInScienceTask: Bool {
        self == .scienceTask || self == .both
    }
}

struct MedicationShareComment: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var authorName: String
    var text: String
    var createdAt: Date
}

struct MedicationShare: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var summary: String
    var body: String
    var drugName: String
    var category: MedicationDiseaseCategory
    var subtype: String
    var therapyKind: MedicationTherapyKind
    var treatmentLine: String
    var drugImageFileNames: [String]
    var recordImageFileNames: [String]
    var status: MedicationShareStatus
    var placement: MedicationSharePlacement
    var isIncentiveEligible: Bool
    /// 高价值经验：浏览需看广告解锁全文
    var isHighValue: Bool
    var viewCount: Int
    var usefulCount: Int
    var authorName: String
    var createdAt: Date
    var publishedAt: Date?
    var auditMessage: String?
    var comments: [MedicationShareComment]
    var baseCashAwarded: Bool
    var viewBonusAwarded: Bool
    var usefulBonusAwarded: Bool
    /// 累计已计入作者奖金池的现金（元，本地演示用整数分的十分之一元：存「分」更稳，这里用「角」×10=元*10 用分）
    var cashCentsEarned: Int

    var categoryPathText: String {
        "\(category.rawValue) > \(subtype) > \(therapyKind.rawValue) > \(treatmentLine)"
    }

    var cashYuanEarned: Double {
        Double(cashCentsEarned) / 100.0
    }
}

struct MedicationCashLedgerEntry: Identifiable, Codable, Equatable {
    let id: String
    let date: Date
    let title: String
    /// 单位：分（正入账，负提现）
    let amountCents: Int
    let balanceAfterCents: Int
}

/// 真实用药站内信（审核、提现等通知）
struct MedicationShareNotice: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var title: String
    var body: String
    var createdAt: Date
    var isRead: Bool
}

enum MedicationShareRules {
    static let baseCashYuan = 5
    static let withdrawMinYuan = 10
    static let viewBonusThreshold = 500
    static let viewBonusYuan = 2
    static let usefulBonusThreshold = 50
    static let usefulBonusYuan = 5
    static let scienceTaskBeans = 10
    static let highValueViewThreshold = 80
    static let adUnlockSeconds = 18
}
