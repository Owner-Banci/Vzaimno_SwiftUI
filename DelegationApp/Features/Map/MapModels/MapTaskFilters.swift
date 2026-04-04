import Foundation

enum MapQuickActionFilter: String, CaseIterable, Identifiable, Hashable {
    case pickup
    case buy
    case carry
    case ride
    case proHelp = "pro_help"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pickup: return "Забрать"
        case .buy: return "Купить"
        case .carry: return "Перенести"
        case .ride: return "Подвезти"
        case .proHelp: return "Помощь от профи"
        }
    }

    var actionType: AnnouncementStructuredData.ActionType {
        switch self {
        case .pickup: return .pickup
        case .buy: return .buy
        case .carry: return .carry
        case .ride: return .ride
        case .proHelp: return .proHelp
        }
    }
}

enum MapTaskPhotoFilter: String, CaseIterable, Hashable {
    case any
    case withPhoto
    case withoutPhoto
}

enum MapTaskSortMode: String, CaseIterable, Identifiable {
    case smart
    case budgetHigh
    case urgentFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "Сначала по пути"
        case .budgetHigh: return "Дороже выше"
        case .urgentFirst: return "Срочные выше"
        }
    }
}

enum MapSheetDetent: CaseIterable {
    case peek
    case half
    case full
}

struct AnnouncementSearchFilters: Equatable {
    var selectedActions: Set<MapQuickActionFilter> = []
    var onlyOnRoute: Bool = false
    var requiresVehicle: Bool?
    var onlyUrgent: Bool = false
    var urgencies: Set<AnnouncementStructuredData.Urgency> = []
    var budgetMin: Int?
    var budgetMax: Int?
    var itemTypes: Set<String> = []
    var helpTypes: Set<String> = []
    var sourceKinds: Set<AnnouncementStructuredData.SourceKind> = []
    var destinationKinds: Set<AnnouncementStructuredData.DestinationKind> = []
    var weightCategories: Set<AnnouncementStructuredData.WeightCategory> = []
    var sizeCategories: Set<AnnouncementStructuredData.SizeCategory> = []
    var needsTrunk: Bool?
    var requiresCarefulHandling: Bool?
    var hasElevator: Bool?
    var needsLoader: Bool?
    var waitOnSite: Bool?
    var callBeforeArrival: Bool?
    var requiresConfirmationCode: Bool?
    var contactless: Bool?
    var requiresReceipt: Bool?
    var photoReportRequired: Bool?
    var photoFilter: MapTaskPhotoFilter = .any

    var hasAnyAdvancedFilter: Bool {
        onlyOnRoute
            || requiresVehicle != nil
            || onlyUrgent
            || !urgencies.isEmpty
            || budgetMin != nil
            || budgetMax != nil
            || !itemTypes.isEmpty
            || !helpTypes.isEmpty
            || !sourceKinds.isEmpty
            || !destinationKinds.isEmpty
            || !weightCategories.isEmpty
            || !sizeCategories.isEmpty
            || needsTrunk != nil
            || requiresCarefulHandling != nil
            || hasElevator != nil
            || needsLoader != nil
            || waitOnSite != nil
            || callBeforeArrival != nil
            || requiresConfirmationCode != nil
            || contactless != nil
            || requiresReceipt != nil
            || photoReportRequired != nil
            || photoFilter != .any
    }

    var advancedFilterCount: Int {
        var count = 0
        if onlyOnRoute { count += 1 }
        if requiresVehicle != nil { count += 1 }
        if onlyUrgent { count += 1 }
        if !urgencies.isEmpty { count += 1 }
        if budgetMin != nil || budgetMax != nil { count += 1 }
        if !itemTypes.isEmpty { count += 1 }
        if !helpTypes.isEmpty { count += 1 }
        if !sourceKinds.isEmpty { count += 1 }
        if !destinationKinds.isEmpty { count += 1 }
        if !weightCategories.isEmpty { count += 1 }
        if !sizeCategories.isEmpty { count += 1 }
        if needsTrunk != nil { count += 1 }
        if requiresCarefulHandling != nil { count += 1 }
        if hasElevator != nil { count += 1 }
        if needsLoader != nil { count += 1 }
        if waitOnSite != nil { count += 1 }
        if callBeforeArrival != nil { count += 1 }
        if requiresConfirmationCode != nil { count += 1 }
        if contactless != nil { count += 1 }
        if requiresReceipt != nil { count += 1 }
        if photoReportRequired != nil { count += 1 }
        if photoFilter != .any { count += 1 }
        return count
    }

    mutating func resetAdvanced() {
        onlyOnRoute = false
        requiresVehicle = nil
        onlyUrgent = false
        urgencies = []
        budgetMin = nil
        budgetMax = nil
        itemTypes = []
        helpTypes = []
        sourceKinds = []
        destinationKinds = []
        weightCategories = []
        sizeCategories = []
        needsTrunk = nil
        requiresCarefulHandling = nil
        hasElevator = nil
        needsLoader = nil
        waitOnSite = nil
        callBeforeArrival = nil
        requiresConfirmationCode = nil
        contactless = nil
        requiresReceipt = nil
        photoReportRequired = nil
        photoFilter = .any
    }

    mutating func resetAll() {
        selectedActions = []
        resetAdvanced()
    }

    mutating func toggleAction(_ filter: MapQuickActionFilter) {
        if selectedActions.contains(filter) {
            selectedActions.remove(filter)
        } else {
            selectedActions.insert(filter)
        }
    }

    func matches(
        announcement: AnnouncementDTO,
        query: String,
        routeDistanceMeters: Double?
    ) -> Bool {
        guard announcement.canAppearOnMap else { return false }

        let structured = announcement.structuredData

        if !selectedActions.isEmpty {
            guard let action = structured.actionType else { return false }
            let allowed = Set(selectedActions.map(\.actionType))
            guard allowed.contains(action) else { return false }
        }

        if onlyOnRoute, routeDistanceMeters == nil {
            return false
        }

        if let requiresVehicle, structured.requiresVehicle != requiresVehicle {
            return false
        }

        if onlyUrgent {
            let urgency = structured.urgency
            guard urgency == .now || urgency == .today else { return false }
        }

        if !urgencies.isEmpty {
            guard let urgency = structured.urgency, urgencies.contains(urgency) else { return false }
        }

        if let budgetMin {
            let upperBound = structured.budgetMax ?? structured.budgetMin ?? announcement.budgetValue
            guard let upperBound, upperBound >= budgetMin else { return false }
        }

        if let budgetMax {
            let lowerBound = structured.budgetMin ?? structured.budgetMax ?? announcement.budgetValue
            guard let lowerBound, lowerBound <= budgetMax else { return false }
        }

        if !itemTypes.isEmpty {
            guard let raw = structured.itemType, itemTypes.contains(raw) else { return false }
        }

        if !helpTypes.isEmpty {
            guard let raw = structured.helpType, helpTypes.contains(raw) else { return false }
        }

        if !sourceKinds.isEmpty {
            guard let source = structured.sourceKind, sourceKinds.contains(source) else { return false }
        }

        if !destinationKinds.isEmpty {
            guard let destination = structured.destinationKind, destinationKinds.contains(destination) else { return false }
        }

        if !weightCategories.isEmpty {
            guard let weight = structured.weightCategory, weightCategories.contains(weight) else { return false }
        }

        if !sizeCategories.isEmpty {
            guard let size = structured.sizeCategory, sizeCategories.contains(size) else { return false }
        }

        if let needsTrunk, structured.needsTrunk != needsTrunk {
            return false
        }

        if let requiresCarefulHandling, structured.requiresCarefulHandling != requiresCarefulHandling {
            return false
        }

        if let hasElevator, structured.hasElevator != hasElevator {
            return false
        }

        if let needsLoader, structured.needsLoader != needsLoader {
            return false
        }

        if let waitOnSite, structured.waitOnSite != waitOnSite {
            return false
        }

        if let callBeforeArrival, structured.callBeforeArrival != callBeforeArrival {
            return false
        }

        if let requiresConfirmationCode, structured.requiresConfirmationCode != requiresConfirmationCode {
            return false
        }

        if let contactless, structured.contactless != contactless {
            return false
        }

        if let requiresReceipt, structured.requiresReceipt != requiresReceipt {
            return false
        }

        if let photoReportRequired, structured.photoReportRequired != photoReportRequired {
            return false
        }

        switch photoFilter {
        case .any:
            break
        case .withPhoto:
            guard announcement.hasAttachedMedia else { return false }
        case .withoutPhoto:
            guard !announcement.hasAttachedMedia else { return false }
        }

        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if !normalizedQuery.isEmpty, !announcement.searchableText.contains(normalizedQuery) {
            return false
        }

        return true
    }
}
