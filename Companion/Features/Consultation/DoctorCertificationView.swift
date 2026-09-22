import SwiftUI
import PhotosUI
import MapKit

struct DoctorCertificationView: View {
    var onSubmitted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var doctorStore = DoctorCertificationStore.shared
    @State private var locationManager = HospitalLocationManager()

    @State private var realName = ""
    @State private var gender = "男"
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var department: DoctorDepartment = .internalMedicine
    @State private var hospitalName = ""
    @State private var idFrontItem: PhotosPickerItem?
    @State private var idBackItem: PhotosPickerItem?
    @State private var qualItem: PhotosPickerItem?
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var cert: DoctorCertification? { doctorStore.certification }

    var body: some View {
        Form {
            if let cert {
                statusSection(cert)
            }
            if cert == nil || cert?.status == .rejected {
                formSections
            }
        }
        .navigationTitle("医生认证")
        .navigationBarTitleDisplayMode(.inline)
        .alert("已提交审核", isPresented: $showSuccess) {
            Button("进入医生主页") {
                onSubmitted()
                dismiss()
            }
        } message: {
            Text("您的认证材料已提交，请留意右上角邮箱中的审核结果。审核通过前可查看患者提问，但无法接诊回复。")
        }
        .alert("无法提交", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            if let cert, realName.isEmpty {
                realName = cert.realName
                gender = cert.gender
                birthDate = cert.birthDate
                hospitalName = cert.hospitalName
                if let dept = DoctorDepartment.allCases.first(where: { $0.rawValue == cert.department }) {
                    department = dept
                }
            }
        }
    }

    @ViewBuilder
    private func statusSection(_ cert: DoctorCertification) -> some View {
        Section("认证状态") {
            switch cert.status {
            case .approved:
                Label("已通过医生认证", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(AppTheme.riskGreen)
            case .pending:
                Label("审核中，请等待平台通知", systemImage: "clock.fill")
                    .foregroundStyle(AppTheme.riskYellow)
            case .rejected:
                Label("未通过，请重新提交", systemImage: "xmark.seal.fill")
                    .foregroundStyle(AppTheme.riskRed)
                if let reason = cert.rejectionReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .none:
                EmptyView()
            }
            LabeledContent("姓名", value: cert.realName)
            LabeledContent("科室", value: cert.department)
            LabeledContent("医院", value: cert.hospitalName)
        }
    }

    @ViewBuilder
    private var formSections: some View {
        Section("基本信息（必填）") {
            TextField("真实姓名", text: $realName)
            Picker("性别", selection: $gender) {
                Text("男").tag("男")
                Text("女").tag("女")
            }
            .pickerStyle(.segmented)
            DatePicker("出生日期", selection: $birthDate, in: ...Date(), displayedComponents: .date)
            Picker("主要负责职位", selection: $department) {
                ForEach(DoctorDepartment.allCases) { dept in
                    Text(dept.rawValue).tag(dept)
                }
            }
        }

        Section("工作医院（必填）") {
            TextField("医院名称", text: $hospitalName)
            Button {
                locationManager.requestLocation()
            } label: {
                HStack {
                    Label(locationManager.isLocating ? "定位中…" : "使用地图定位", systemImage: "location.fill")
                    Spacer()
                    if locationManager.coordinate != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.riskGreen)
                    }
                }
            }
            .onChange(of: locationManager.hospitalName) { _, name in
                if hospitalName.isEmpty, !name.isEmpty {
                    hospitalName = name
                }
            }
            .onChange(of: locationManager.coordinate?.latitude) { _, _ in
                if let c = locationManager.coordinate {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: c,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }

            if let coord = locationManager.coordinate {
                Map(position: $cameraPosition, interactionModes: []) {
                    Marker(hospitalName.isEmpty ? "工作医院" : hospitalName, coordinate: coord)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(String(format: "定位：%.4f, %.4f", coord.latitude, coord.longitude))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        Section("证件上传（选填）") {
            photoRow(title: "身份证正面", item: $idFrontItem)
            photoRow(title: "身份证背面", item: $idBackItem)
            photoRow(title: "医师资格证", item: $qualItem)
            Text("提交后将进入人工审核，结果会通过医生主页右上角邮箱通知。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section {
            Button("提交认证") {
                Task { await submit() }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func photoRow(title: String, item: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: item, matching: .images) {
            HStack {
                Text(title)
                Spacer()
                Text(item.wrappedValue == nil ? "未上传" : "已选择")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func submit() async {
        let front = await loadData(from: idFrontItem)
        let back = await loadData(from: idBackItem)
        let qual = await loadData(from: qualItem)
        let result = doctorStore.submit(
            realName: realName,
            gender: gender,
            birthDate: birthDate,
            department: department,
            hospitalName: hospitalName,
            latitude: locationManager.coordinate?.latitude,
            longitude: locationManager.coordinate?.longitude,
            idCardFrontData: front,
            idCardBackData: back,
            qualificationData: qual
        )
        switch result {
        case .success:
            showSuccess = true
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadData(from item: PhotosPickerItem?) async -> Data? {
        guard let item else { return nil }
        return try? await item.loadTransferable(type: Data.self)
    }
}

#Preview {
    NavigationStack {
        DoctorCertificationView()
    }
}
