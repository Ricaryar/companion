import Foundation

enum SymptomTag: String, CaseIterable, Codable, Identifiable {
    case all = "全部"
    case headache = "头痛"
    case fever = "发热"
    case cough = "咳嗽"
    case diarrhea = "腹泻"
    case rash = "皮疹"
    case chestTightness = "胸闷"
    case fatigue = "乏力"
    case other = "其他"

    var id: String { rawValue }

    static var askOptions: [SymptomTag] {
        allCases.filter { $0 != .all }
    }
}

enum SymptomDuration: String, CaseIterable, Codable, Identifiable {
    case hours = "几小时"
    case days1to3 = "1~3天"
    case days4to7 = "4~7天"
    case weeks1to2 = "1~2周"
    case over2weeks = "2周以上"

    var id: String { rawValue }
}

enum ConsultationStatus: String, Codable, Identifiable {
    case waiting = "待接诊"
    case active = "咨询中"
    case closed = "已关闭"
    case cancelled = "已取消"

    var id: String { rawValue }
}

enum ChatSender: String, Codable {
    case user
    case doctor
    case system
}

struct DoctorProfile: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var department: String
    var title: String
    var hospital: String
    var rating: Double
    var avatarSymbol: String

    enum CodingKeys: String, CodingKey {
        case id, name, department, title, hospital, rating, avatarSymbol
    }

    init(
        id: String,
        name: String,
        department: String,
        title: String,
        hospital: String,
        rating: Double,
        avatarSymbol: String
    ) {
        self.id = id
        self.name = name
        self.department = department
        self.title = title
        self.hospital = hospital
        self.rating = rating
        self.avatarSymbol = avatarSymbol
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        department = try c.decode(String.self, forKey: .department)
        title = try c.decode(String.self, forKey: .title)
        hospital = try c.decodeIfPresent(String.self, forKey: .hospital) ?? "合作医院"
        rating = try c.decode(Double.self, forKey: .rating)
        avatarSymbol = try c.decode(String.self, forKey: .avatarSymbol)
    }
}

struct ChatMessage: Codable, Equatable, Identifiable {
    var id: String
    var sender: ChatSender
    var text: String
    var createdAt: Date
}

struct ConsultationRating: Codable, Equatable {
    var speedStars: Int
    var expertiseStars: Int
    var resolved: Bool
    var createdAt: Date

    var isNegative: Bool {
        speedStars <= 1 || expertiseStars <= 1 || !resolved
    }

    var averageStars: Double {
        Double(speedStars + expertiseStars) / 2.0
    }
}

struct Consultation: Codable, Equatable, Identifiable {
    var id: String
    var createdAt: Date
    var status: ConsultationStatus

    var gender: String
    var age: Int
    var symptom: SymptomTag
    var duration: SymptomDuration
    var detail: String
    var medicationNote: String
    var imageCount: Int

    var chargedBeans: Int
    var refunded: Bool

    var doctor: DoctorProfile?
    var assignedDoctorId: String?
    var doctorFirstReplyAt: Date?
    var closedAt: Date?
    var waitingDeadline: Date

    var messages: [ChatMessage]
    var followUpCount: Int
    var freeFollowUpUsed: Bool

    var rating: ConsultationRating?
    var isPublic: Bool?
    var viewCount: Int
    var publicPublishedAt: Date?

    var shortTitle: String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 15 { return trimmed.isEmpty ? symptom.rawValue : trimmed }
        return String(trimmed.prefix(15))
    }

    var remainingDialogSeconds: TimeInterval? {
        guard let start = doctorFirstReplyAt else { return nil }
        let end = start.addingTimeInterval(ConsultationRules.dialogDuration)
        return end.timeIntervalSinceNow
    }

    var isDialogExpired: Bool {
        guard let remaining = remainingDialogSeconds else { return false }
        return remaining <= 0
    }

    var canFollowUp: Bool {
        status == .active && !isDialogExpired && followUpCount < ConsultationRules.maxFollowUps
    }

    var freeFollowUpsLeft: Int {
        freeFollowUpUsed ? 0 : 1
    }
}

enum ConsultationError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}

enum ConsultationRules {
    static let baseAskCost = 150
    static let monthCardAskCost = 120
    static let followUpCost = 30
    static let maxFollowUps = 5
    static let dialogDuration: TimeInterval = 6 * 60 * 60
    static let waitingTimeout: TimeInterval = 24 * 60 * 60
    static let ratingReward = 5
    static let detailMin = 10
    static let detailMax = 300
    static let maxImages = 3
}
