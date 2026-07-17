import SwiftUI

private enum MoreRoute: Hashable {
    case doctorInbox
    case doctorChat(String)
}

/// 底部 Tab「更多」：文件、设置、医生认证/在线回答
struct MoreTabView: View {
    @State private var doctorStore = DoctorCertificationStore.shared
    @State private var store = ConsultationStore.shared
    @State private var deepLink = ConsultationDeepLink.shared
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                NavigationLink {
                    DocumentsLibraryView(
                        navigationTitle: "文件",
                        showMedicalShortcuts: true
                    )
                } label: {
                    Label("文件", systemImage: "folder.fill")
                }

                NavigationLink {
                    MedicationShareCommunityView()
                } label: {
                    Label("真实用药", systemImage: "pills.fill")
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("设置", systemImage: "gearshape.fill")
                }

                if doctorStore.isApprovedDoctor {
                    NavigationLink(value: MoreRoute.doctorInbox) {
                        HStack {
                            Label("在线回答", systemImage: "stethoscope")
                            Spacer()
                            if store.doctorUnreadTotal > 0 {
                                Text("\(store.doctorUnreadTotal)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                } else {
                    NavigationLink {
                        DoctorCertificationView()
                    } label: {
                        Label("医生认证", systemImage: "person.text.rectangle")
                    }
                }
            }
            .navigationTitle("更多")
            .navigationDestination(for: MoreRoute.self) { route in
                switch route {
                case .doctorInbox:
                    DoctorInboxView()
                case .doctorChat(let id):
                    DoctorActiveChatView(consultationId: id)
                }
            }
        }
        .onAppear {
            _ = doctorStore.changeToken
            openDoctorChatIfNeeded()
        }
        .onChange(of: deepLink.pendingDoctorChatId) { _, _ in
            openDoctorChatIfNeeded()
        }
        .onChange(of: deepLink.shouldSelectMoreTab) { _, need in
            if need {
                openDoctorChatIfNeeded()
            }
        }
    }

    private func openDoctorChatIfNeeded() {
        guard let id = deepLink.consumePendingDoctorChatId() else { return }
        path.append(MoreRoute.doctorChat(id))
    }
}

#Preview {
    MoreTabView()
        .modelContainer(CompanionModelContainer.make(inMemory: true))
}
