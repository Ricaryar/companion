import Foundation

enum RegimenRepositoryError: Error {
    case catalogNotFound
    case regimenNotFound
}

struct RegimenRepository {
    static let shared = RegimenRepository()

    private(set) var catalog: RegimenCatalog?

    init() {
        catalog = Self.loadCatalog()
    }

    func allRegimens() -> [RegimenDef] {
        catalog?.regimens ?? []
    }

    func regimen(for code: String) -> RegimenDef? {
        let primaryCode = code.split(separator: "|").first.map(String.init) ?? code
        return catalog?.regimens.first { $0.code == primaryCode }
    }

    func resolvedRegimens(forStoredCode code: String) -> [RegimenDef] {
        code.split(separator: "|").compactMap { regimen(for: String($0)) }
    }

    func regimens(
        for line: TreatmentLineKind,
        category: RegimenCategory? = nil,
        maintenanceOnly: Bool = false
    ) -> [RegimenDef] {
        allRegimens().filter { def in
            if let category, def.regimenCategory != category { return false }
            if maintenanceOnly { return def.isMaintenanceOption }
            return def.supportedLines.contains(line.rawValue) || (line == .maintenance && def.isMaintenanceOption)
        }
    }

    func primaryRegimens(
        for line: TreatmentLineKind,
        maintenanceOnly: Bool = false
    ) -> [RegimenDef] {
        regimens(for: line, maintenanceOnly: maintenanceOnly).filter(\.canUseAsPrimary)
    }

    func groupedPrimaryRegimens(
        for line: TreatmentLineKind,
        maintenanceOnly: Bool = false
    ) -> [(category: RegimenCategory, regimens: [RegimenDef])] {
        let ordered = catalog?.categories.sorted { $0.sortOrder < $1.sortOrder } ?? []
        let categoryOrder: [RegimenCategory] = ordered.compactMap { RegimenCategory(rawValue: $0.code) }
            + RegimenCategory.allCases.filter { c in !ordered.contains(where: { $0.code == c.rawValue }) }

        return categoryOrder.compactMap { cat in
            let items = regimens(for: line, category: cat, maintenanceOnly: maintenanceOnly).filter(\.canUseAsPrimary)
            return items.isEmpty ? nil : (cat, items)
        }
    }

    func addonRegimens(for line: TreatmentLineKind) -> [(category: RegimenCategory, regimens: [RegimenDef])] {
        let ordered = catalog?.categories.sorted { $0.sortOrder < $1.sortOrder } ?? []
        let categoryOrder: [RegimenCategory] = ordered.compactMap { RegimenCategory(rawValue: $0.code) }
            + RegimenCategory.allCases.filter { c in !ordered.contains(where: { $0.code == c.rawValue }) }

        return categoryOrder.compactMap { cat in
            let items = allRegimens().filter { def in
                guard def.canUseAsAddon, def.regimenCategory == cat else { return false }
                return def.supportedLines.contains(line.rawValue) || line == .maintenance
            }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    func regimens(forCodes codes: [String]) -> [RegimenDef] {
        codes.compactMap { regimen(for: $0) }
    }

    func groupedAllSelectableRegimens() -> [(category: RegimenCategory, regimens: [RegimenDef])] {
        let ordered = catalog?.categories.sorted { $0.sortOrder < $1.sortOrder } ?? []
        let categoryOrder: [RegimenCategory] = ordered.compactMap { RegimenCategory(rawValue: $0.code) }
            + RegimenCategory.allCases.filter { c in !ordered.contains(where: { $0.code == c.rawValue }) }

        return categoryOrder.compactMap { cat in
            var seen = Set<String>()
            let items = allRegimens().filter { def in
                guard def.regimenCategory == cat else { return false }
                guard def.canUseAsPrimary || def.canUseAsAddon else { return false }
                guard !seen.contains(def.code) else { return false }
                seen.insert(def.code)
                return true
            }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    func groupedAllPrimaryRegimens() -> [(category: RegimenCategory, regimens: [RegimenDef])] {
        groupedRegimensUnfiltered(primaryOnly: true)
    }

    func groupedAllAddonRegimens() -> [(category: RegimenCategory, regimens: [RegimenDef])] {
        let ordered = catalog?.categories.sorted { $0.sortOrder < $1.sortOrder } ?? []
        let categoryOrder: [RegimenCategory] = ordered.compactMap { RegimenCategory(rawValue: $0.code) }
            + RegimenCategory.allCases.filter { c in !ordered.contains(where: { $0.code == c.rawValue }) }

        return categoryOrder.compactMap { cat in
            let items = allRegimens().filter { $0.canUseAsAddon && $0.regimenCategory == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    private func groupedRegimensUnfiltered(primaryOnly: Bool) -> [(category: RegimenCategory, regimens: [RegimenDef])] {
        let ordered = catalog?.categories.sorted { $0.sortOrder < $1.sortOrder } ?? []
        let categoryOrder: [RegimenCategory] = ordered.compactMap { RegimenCategory(rawValue: $0.code) }
            + RegimenCategory.allCases.filter { c in !ordered.contains(where: { $0.code == c.rawValue }) }

        return categoryOrder.compactMap { cat in
            let items = allRegimens().filter { def in
                guard def.regimenCategory == cat else { return false }
                return primaryOnly ? def.canUseAsPrimary : true
            }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    func groupedRegimens(
        for line: TreatmentLineKind,
        maintenanceOnly: Bool = false
    ) -> [(category: RegimenCategory, regimens: [RegimenDef])] {
        let ordered = catalog?.categories.sorted { $0.sortOrder < $1.sortOrder } ?? []
        let categoryOrder: [RegimenCategory] = ordered.compactMap { RegimenCategory(rawValue: $0.code) }
            + RegimenCategory.allCases.filter { c in !ordered.contains(where: { $0.code == c.rawValue }) }

        return categoryOrder.compactMap { cat in
            let items = regimens(for: line, category: cat, maintenanceOnly: maintenanceOnly)
            return items.isEmpty ? nil : (cat, items)
        }
    }

    func categoryDisplayName(for code: String) -> String {
        catalog?.categories.first { $0.code == code }?.displayName
            ?? RegimenCategory(rawValue: code)?.displayName
            ?? code
    }

    private static func loadCatalog() -> RegimenCatalog? {
        guard let url = Bundle.main.url(forResource: "regimens", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RegimenCatalog.self, from: data)
    }
}

struct RiskRulesRepository {
    static let shared = RiskRulesRepository()

    private(set) var catalog: RiskRulesCatalog?

    init() {
        catalog = Self.loadCatalog()
    }

    private static func loadCatalog() -> RiskRulesCatalog? {
        guard let url = Bundle.main.url(forResource: "rules", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RiskRulesCatalog.self, from: data)
    }
}
