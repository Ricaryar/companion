import Foundation
import CoreLocation

enum DoctorCertStatus: String, Codable {
    case none
    case pending
    case approved
    case rejected
}

enum DoctorDepartment: String, CaseIterable, Identifiable, Codable {
    case internalMedicine = "内科"
    case surgery = "外科"
    case orthopedics = "骨科"
    case pediatrics = "儿科"
    case dermatology = "皮肤科"
    case general = "全科"
    case respiratory = "呼吸内科"
    case gastroenterology = "消化内科"
    case oncology = "肿瘤科"
    case other = "其他"

    var id: String { rawValue }
}

struct DoctorCertification: Codable, Equatable {
    var id: String
    var accountId: String
    var realName: String
    var gender: String
    var birthDate: Date
    var department: String
    var hospitalName: String
    var hospitalLatitude: Double?
    var hospitalLongitude: Double?
    var idCardFrontFilename: String?
    var idCardBackFilename: String?
    var qualificationFilename: String?
    var status: DoctorCertStatus
    var submittedAt: Date
    var approvedAt: Date?
    var rejectionReason: String?

    func toDoctorProfile() -> DoctorProfile {
        DoctorProfile(
            id: id,
            name: realName,
            department: department,
            title: "认证医师",
            hospital: hospitalName,
            rating: 5.0,
            avatarSymbol: "stethoscope.circle.fill"
        )
    }
}

enum DoctorCertError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}

@Observable
final class DoctorCertificationStore {
    static let shared = DoctorCertificationStore()

    private var certificationsByAccount: [String: DoctorCertification] = [:]
    private(set) var changeToken = 0

    private let defaults = UserDefaults.standard
    private let certMapKey = "doctor.certifications.byAccount"
    private let legacyCertKey = "doctor.certification"
    private let imageFolder: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("Companion/DoctorCerts", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        imageFolder = folder
        load()
    }

    var certification: DoctorCertification? {
        _ = changeToken
        guard let accountId = AccountStore.shared.currentUser?.id else { return nil }
        return certificationsByAccount[accountId]
    }

    var isApprovedDoctor: Bool {
        certification?.status == .approved
    }

    var isPendingReview: Bool {
        certification?.status == .pending
    }

    var doctorProfile: DoctorProfile? {
        guard isApprovedDoctor else { return nil }
        return certification?.toDoctorProfile()
    }

    private func bump() {
        changeToken += 1
    }

    private func load() {
        if let data = defaults.data(forKey: certMapKey),
           let decoded = try? JSONDecoder().decode([String: DoctorCertification].self, from: data) {
            certificationsByAccount = decoded
        } else if let data = defaults.data(forKey: legacyCertKey),
                  var legacy = try? JSONDecoder().decode(DoctorCertification.self, from: data) {
            if legacy.accountId.isEmpty {
                legacy.accountId = AccountStore.shared.currentUser?.id ?? "legacy"
            }
            certificationsByAccount[legacy.accountId] = legacy
            saveMap()
            defaults.removeObject(forKey: legacyCertKey)
        }
    }

    private func saveMap() {
        guard let data = try? JSONEncoder().encode(certificationsByAccount) else { return }
        defaults.set(data, forKey: certMapKey)
        bump()
    }

    private func persist(_ cert: DoctorCertification) {
        certificationsByAccount[cert.accountId] = cert
        saveMap()
    }

    /// 提交后进入待审核，不再自动通过。
    @discardableResult
    func submit(
        realName: String,
        gender: String,
        birthDate: Date,
        department: DoctorDepartment,
        hospitalName: String,
        latitude: Double?,
        longitude: Double?,
        idCardFrontData: Data?,
        idCardBackData: Data?,
        qualificationData: Data?
    ) -> Result<DoctorCertification, DoctorCertError> {
        guard let accountId = AccountStore.shared.currentUser?.id else {
            return .failure(.message("请先登录医生账号"))
        }
        guard AccountStore.shared.currentUser?.role == .doctor else {
            return .failure(.message("仅医生账号可提交认证"))
        }

        let trimmedName = realName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.message("请填写真实姓名")) }
        guard !hospitalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.message("请填写工作医院"))
        }

        let existing = certificationsByAccount[accountId]
        let id = existing?.id ?? UUID().uuidString
        var cert = DoctorCertification(
            id: id,
            accountId: accountId,
            realName: trimmedName,
            gender: gender,
            birthDate: birthDate,
            department: department.rawValue,
            hospitalName: hospitalName.trimmingCharacters(in: .whitespacesAndNewlines),
            hospitalLatitude: latitude,
            hospitalLongitude: longitude,
            idCardFrontFilename: nil,
            idCardBackFilename: nil,
            qualificationFilename: nil,
            status: .pending,
            submittedAt: .now,
            approvedAt: nil,
            rejectionReason: nil
        )

        if let data = idCardFrontData {
            cert.idCardFrontFilename = saveImage(data, prefix: "id-front")
        }
        if let data = idCardBackData {
            cert.idCardBackFilename = saveImage(data, prefix: "id-back")
        }
        if let data = qualificationData {
            cert.qualificationFilename = saveImage(data, prefix: "qual")
        }

        persist(cert)
        DoctorAuditMailboxStore.shared.notifyCertSubmitted(accountId: accountId, realName: trimmedName)
        return .success(cert)
    }

    func markApproved(accountId: String) {
        guard var cert = certificationsByAccount[accountId] else { return }
        cert.status = .approved
        cert.approvedAt = .now
        cert.rejectionReason = nil
        persist(cert)
        DoctorAuditMailboxStore.shared.notifyCertApproved(accountId: accountId, realName: cert.realName)
    }

    func markRejected(accountId: String, reason: String) {
        guard var cert = certificationsByAccount[accountId] else { return }
        cert.status = .rejected
        cert.approvedAt = nil
        cert.rejectionReason = reason
        persist(cert)
        DoctorAuditMailboxStore.shared.notifyCertRejected(
            accountId: accountId,
            realName: cert.realName,
            reason: reason
        )
    }

    private func saveImage(_ data: Data, prefix: String) -> String {
        let name = "\(prefix)-\(UUID().uuidString).jpg"
        let url = imageFolder.appendingPathComponent(name)
        try? data.write(to: url, options: [.atomic])
        return name
    }
}
