import SwiftUI
import PhotosUI
import MapKit

struct DoctorCertificationView: View {
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

    var body: some View {
        Form {
            if doctorStore.isApprovedDoctor, let cert = doctorStore.certification {
                Section("认证状态") {
                    Label("已通过医生认证", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(AppTheme.riskGreen)
                    LabeledContent("姓名", value: cert.realName)
                    LabeledContent("科室", value: cert.department)
                    LabeledContent("医院", value: cert.hospitalName)
                }
            } else {
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

                Section("证件上传（测试版选填）") {
                    photoRow(title: "身份证正面", item: $idFrontItem)
                    photoRow(title: "身份证背面", item: $idBackItem)
                    photoRow(title: "医师资格证", item: $qualItem)
                    Text("测试版本可不传证件图片，提交后将自动通过认证。")
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
        }
        .navigationTitle(doctorStore.isApprovedDoctor ? "医生认证" : "医生认证")
        .navigationBarTitleDisplayMode(.inline)
        .alert("认证成功", isPresented: $showSuccess) {
            Button("好的") { dismiss() }
        } message: {
            Text("您已成为认证医生，可在「更多」中进入「在线回答」接诊。")
        }
        .alert("无法提交", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
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
