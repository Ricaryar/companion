import Foundation

struct SideEffectRepository {
    static let shared = SideEffectRepository()

    private(set) var catalog: SideEffectCatalog?

    init() {
        catalog = Self.loadCatalog()
    }

    func drugProfiles(forRegimenCodes codes: [String]) -> [DrugSideEffectProfile] {
        guard let catalog else { return [] }
        var drugCodes: [String] = []
        var seen = Set<String>()
        for code in codes {
            for part in code.split(separator: "|").map(String.init) {
                let mapped = catalog.regimenDrugs[part] ?? []
                for drugCode in mapped where !seen.contains(drugCode) {
                    seen.insert(drugCode)
                    drugCodes.append(drugCode)
                }
            }
        }
        return drugCodes.compactMap { drugProfile(for: $0) }
    }

    func drugProfiles(forRegimenCode code: String) -> [DrugSideEffectProfile] {
        drugProfiles(forRegimenCodes: [code])
    }

    func drugProfile(for code: String) -> DrugSideEffectProfile? {
        catalog?.drugs.first { $0.code == code }
    }

    func aggregatedSideEffects(forRegimenCodes codes: [String]) -> [AggregatedSideEffect] {
        var grouped: [String: (entry: SideEffectEntry, drugs: Set<String>)] = [:]
        for profile in drugProfiles(forRegimenCodes: codes) {
            for entry in profile.sideEffects {
                let key = entry.symptomKey + "|" + entry.label
                if var existing = grouped[key] {
                    existing.drugs.insert(profile.displayName)
                    grouped[key] = existing
                } else {
                    grouped[key] = (entry, [profile.displayName])
                }
            }
        }
        return grouped.map { key, value in
            AggregatedSideEffect(
                id: key,
                entry: value.entry,
                drugNames: value.drugs.sorted()
            )
        }
        .sorted { $0.entry.label < $1.entry.label }
    }

    func checkInRelevantTips(forRegimenCodes codes: [String]) -> [AggregatedSideEffect] {
        let tracked = Set(SideEffectSymptomKey.allCases.map(\.rawValue))
        return aggregatedSideEffects(forRegimenCodes: codes)
            .filter { tracked.contains($0.entry.symptomKey) }
    }

    private static func loadCatalog() -> SideEffectCatalog? {
        guard let url = Bundle.main.url(forResource: "sideEffectTips", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SideEffectCatalog.self, from: data)
    }
}
