import Foundation
import CoreLocation

enum DoctorCertStatus: String, Codable {
    case none
    case approved
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

    private(set) var certification: DoctorCertification?
    private(set) var changeToken = 0

    private let defaults = UserDefaults.standard
    private let certKey = "doctor.certification"
    private let imageFolder: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("Companion/DoctorCerts", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        imageFolder = folder
        load()
    }

    var isApprovedDoctor: Bool {
        _ = changeToken
        return certification?.status == .approved
    }

    var doctorProfile: DoctorProfile? {
        guard isApprovedDoctor else { return nil }
        return certification?.toDoctorProfile()
    }

    private func bump() {
        changeToken += 1
    }

    private func load() {
        guard let data = defaults.data(forKey: certKey),
              let decoded = try? JSONDecoder().decode(DoctorCertification.self, from: data) else {
            certification = nil
            return
        }
        certification = decoded
    }

    private func save() {
        guard let certification,
              let data = try? JSONEncoder().encode(certification) else { return }
        defaults.set(data, forKey: certKey)
        bump()
    }

    /// 测试版：提交后自动通过认证。
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
        let trimmedName = realName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(.message("请填写真实姓名")) }
        guard !hospitalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.message("请填写工作医院"))
        }

        let id = certification?.id ?? UUID().uuidString
        var cert = DoctorCertification(
            id: id,
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
            status: .approved,
            submittedAt: .now,
            approvedAt: .now
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

        certification = cert
        save()
        return .success(cert)
    }

    private func saveImage(_ data: Data, prefix: String) -> String {
        let name = "\(prefix)-\(UUID().uuidString).jpg"
        let url = imageFolder.appendingPathComponent(name)
        try? data.write(to: url, options: [.atomic])
        return name
    }
}
