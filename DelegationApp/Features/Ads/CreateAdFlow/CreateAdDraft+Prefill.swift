//
//  CreateAdDraft+Prefill.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 27.02.2026.
//

import Foundation

extension CreateAdDraft {

    static func prefilled(from ann: AnnouncementDTO) -> CreateAdDraft {
        let draft = CreateAdDraft()

        draft.category = Category(rawValue: ann.category)
        draft.title = ann.title
        draft.notes = ann.data["notes"]?.stringValue ?? ""
        draft.taskBrief =
            ann.data["task_brief"]?.stringValue
            ?? ann.data["short_comment"]?.stringValue
            ?? ""

        draft.budget = stringValue(from: ann.data["budget"])
        draft.budgetMin = ann.budgetMinValue.map(String.init) ?? stringValue(from: ann.data["budget_min"])
        draft.budgetMax = ann.budgetMaxValue.map(String.init) ?? stringValue(from: ann.data["budget_max"])
        if draft.budgetMin.isEmpty, draft.budgetMax.isEmpty {
            let legacyBudget = stringValue(from: ann.data["budget"])
            draft.budgetMin = legacyBudget
            draft.budgetMax = legacyBudget
        }

        if let audience = ann.data["audience"]?.stringValue, let value = Audience(rawValue: audience) {
            draft.audience = value
        }
        if let contactMethod = ann.data["contact_method"]?.stringValue, let value = ContactMethod(rawValue: contactMethod) {
            draft.contactMethod = value
        }
        draft.contactName = ann.data["contact_name"]?.stringValue ?? ""
        draft.contactPhone = ann.data["contact_phone"]?.stringValue ?? ""

        let sourceAddress =
            ann.data["source_address"]?.stringValue
            ?? ann.data["pickup_address"]?.stringValue
            ?? ann.data["address"]?.stringValue
            ?? ""
        let destinationAddress =
            ann.data["destination_address"]?.stringValue
            ?? ann.data["dropoff_address"]?.stringValue
            ?? ""

        draft.pickupAddress = sourceAddress
        draft.dropoffAddress = destinationAddress
        draft.helpAddress = sourceAddress
        draft.helpDestinationAddress = destinationAddress

        let startDate = parseDate(from: ann.data["start_at"]?.stringValue)
        let endDate = parseDate(from: ann.data["end_at"]?.stringValue)
        if let startDate {
            draft.startDate = startDate
        }
        if let endDate {
            draft.endDate = endDate
        }

        draft.actionType = actionType(from: ann)
        draft.sourceKind = sourceKind(from: ann.data["source_kind"]?.stringValue, legacyCategory: ann.category)
        draft.destinationKind = destinationKind(from: ann.data["destination_kind"]?.stringValue)
        draft.itemType = itemType(from: ann)
        draft.purchaseType = purchaseType(from: ann)
        draft.helpType = helpType(from: ann)
        draft.urgency = urgency(from: ann, startDate: startDate)
        draft.weightCategory = weightCategory(from: ann.data["weight_category"]?.stringValue)
        draft.sizeCategory = sizeCategory(from: ann.data["size_category"]?.stringValue)

        draft.requiresVehicle = ann.data["requires_vehicle"]?.boolValue ?? (draft.actionType == .ride)
        draft.needsTrunk = ann.data["needs_trunk"]?.boolValue ?? false
        draft.requiresCarefulHandling = ann.data["requires_careful_handling"]?.boolValue ?? false
        draft.requiresLiftToFloor = ann.data["requires_lift_to_floor"]?.boolValue ?? false
        draft.hasElevator = ann.data["has_elevator"]?.boolValue ?? draft.hasElevator
        draft.needLoader = ann.data["needs_loader"]?.boolValue
            ?? ann.data["need_loader"]?.boolValue
            ?? draft.needLoader
        draft.waitOnSite = ann.data["wait_on_site"]?.boolValue ?? false
        draft.contactless = ann.data["contactless"]?.boolValue ?? false
        draft.requiresReceipt = ann.data["requires_receipt"]?.boolValue ?? false
        draft.requiresConfirmationCode = ann.data["requires_confirmation_code"]?.boolValue ?? false
        draft.callBeforeArrival = ann.data["call_before_arrival"]?.boolValue ?? false
        draft.photoReportRequired = ann.data["photo_report_required"]?.boolValue ?? false

        draft.hasEndTime = ann.data["has_end_time"]?.boolValue ?? false
        draft.floor = stringValue(from: ann.data["floor"])
        draft.estimatedTaskMinutes = stringValue(from: ann.data["estimated_task_minutes"])
        draft.waitingMinutes = stringValue(from: ann.data["waiting_minutes"])
        draft.cargoLength = stringValue(from: ann.data["cargo_length_cm"] ?? ann.data["cargo_length"])
        draft.cargoWidth = stringValue(from: ann.data["cargo_width_cm"] ?? ann.data["cargo_width"])
        draft.cargoHeight = stringValue(from: ann.data["cargo_height_cm"] ?? ann.data["cargo_height"])

        if draft.actionType == .proHelp, draft.taskBrief.isEmpty {
            draft.taskBrief = inferredProHelpBrief(from: ann)
        }

        return draft
    }

    func applyModerationMarks(from ann: AnnouncementDTO) {
        guard let reasons = ann.moderationPayload?.reasons else { return }
        var dictionary: [String: DraftModerationMark] = [:]

        for reason in reasons where !reason.isTechnicalIssue {
            let mark = DraftModerationMark(
                severity: reason.severity,
                code: reason.code,
                details: reason.details
            )
            if let existing = dictionary[reason.field], existing.severity >= mark.severity {
                continue
            }
            dictionary[reason.field] = mark
        }

        moderationMarks = dictionary
    }

    private static func actionType(from ann: AnnouncementDTO) -> CreateAdDraft.UserActionType? {
        if let raw = ann.data["user_action_type"]?.stringValue, let value = CreateAdDraft.UserActionType(rawValue: raw) {
            return value
        }

        if let raw = ann.data["action_type"]?.stringValue {
            if let value = CreateAdDraft.UserActionType(rawValue: raw) {
                return value
            }
            if raw == "pro_help" {
                return .proHelp
            }
        }

        if let resolved = ann.data["resolved_category"]?.stringValue {
            switch resolved {
            case "pickup_point", "handoff":
                return .pickup
            case "buy":
                return .buy
            case "carry":
                return .carry
            case "ride":
                return .ride
            case "pro_help":
                return .proHelp
            default:
                break
            }
        }

        if ann.data["help_type"]?.stringValue != nil {
            return .proHelp
        }
        if ann.data["requires_receipt"]?.boolValue == true {
            return .buy
        }
        if ann.data["requires_confirmation_code"]?.boolValue == true {
            return .pickup
        }
        if ann.category == "delivery" {
            return .pickup
        }

        if ann.data["needs_loader"]?.boolValue == true
            || ann.data["requires_lift_to_floor"]?.boolValue == true
            || ann.data["need_loader"]?.boolValue == true {
            return .carry
        }

        return .other
    }

    private static func sourceKind(from raw: String?, legacyCategory: String) -> CreateAdDraft.SourceKind? {
        switch raw {
        case "person":
            return .person
        case "pickupPoint", "pickup_point":
            return .pickupPoint
        case "store", "pharmacy", "venue":
            return .venue
        case "address":
            return .address
        case "office":
            return .office
        case "other":
            return .other
        case nil:
            return legacyCategory == "help" ? .address : nil
        default:
            return .other
        }
    }

    private static func destinationKind(from raw: String?) -> CreateAdDraft.DestinationKind? {
        switch raw {
        case "person":
            return .person
        case "address":
            return .address
        case "office":
            return .office
        case "entrance":
            return .entrance
        case "metro":
            return .metro
        case "other":
            return .other
        case nil:
            return nil
        default:
            return .other
        }
    }

    private static func itemType(from ann: AnnouncementDTO) -> CreateAdDraft.ItemType? {
        guard let raw = ann.data["item_type"]?.stringValue else { return nil }

        switch raw {
        case "groceries":
            return .groceries
        case "documents":
            return .documents
        case "electronics":
            return .electronics
        case "fragile_item":
            return .fragileItem
        case "bags":
            return .bags
        case "bulky_item", "box":
            return .bulkyItem
        case "parcel", "personalItem", "other":
            return .other
        default:
            return .other
        }
    }

    private static func purchaseType(from ann: AnnouncementDTO) -> CreateAdDraft.PurchaseType? {
        if let raw = ann.data["purchase_type"]?.stringValue {
            return CreateAdDraft.PurchaseType(rawValue: raw) ?? legacyPurchaseType(from: raw)
        }

        if actionType(from: ann) == .buy, let raw = ann.data["item_type"]?.stringValue {
            return legacyPurchaseType(from: raw) ?? .groceries
        }

        return nil
    }

    private static func helpType(from ann: AnnouncementDTO) -> CreateAdDraft.HelpType? {
        guard let raw = ann.data["help_type"]?.stringValue else { return nil }

        switch raw {
        case "consultation":
            return .consultation
        case "setup_device":
            return .setupDevice
        case "install_or_connect":
            return .installOrConnect
        case "minor_repair":
            return .minorRepair
        case "diagnose":
            return .diagnose
        default:
            return .other
        }
    }

    private static func urgency(from ann: AnnouncementDTO, startDate: Date?) -> CreateAdDraft.Urgency {
        if let raw = ann.data["urgency"]?.stringValue, let value = CreateAdDraft.Urgency(rawValue: raw) {
            return value
        }
        return inferUrgency(from: startDate)
    }

    private static func weightCategory(from raw: String?) -> CreateAdDraft.WeightCategory? {
        guard let raw else { return nil }
        switch raw {
        case "up_to_1kg", "upTo1kg":
            return .upTo1kg
        case "up_to_3kg", "upTo3kg":
            return .upTo3kg
        case "up_to_7kg", "upTo7kg":
            return .upTo7kg
        case "up_to_15kg", "upTo15kg":
            return .upTo15kg
        case "over_15kg", "over15kg":
            return .over15kg
        default:
            return nil
        }
    }

    private static func sizeCategory(from raw: String?) -> CreateAdDraft.SizeCategory? {
        guard let raw else { return nil }
        switch raw {
        case "pocket":
            return .pocket
        case "hand":
            return .hand
        case "backpack":
            return .backpack
        case "trunk":
            return .trunk
        case "bulky":
            return .bulky
        default:
            return nil
        }
    }

    private static func inferredProHelpBrief(from ann: AnnouncementDTO) -> String {
        let title = ann.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "" }

        let prefix = "Быстрая помощь:"
        if title.hasPrefix(prefix) {
            return title.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return title
    }

    private static func inferUrgency(from startDate: Date?) -> CreateAdDraft.Urgency {
        guard let startDate else { return .today }

        let now = Date()
        let calendar = Calendar.current
        let delta = startDate.timeIntervalSince(now)

        if delta <= 60 * 60 {
            return .now
        }
        if calendar.isDate(startDate, inSameDayAs: now) {
            return .today
        }
        return .scheduled
    }

    private static func parseDate(from raw: String?) -> Date? {
        guard let raw else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    private static func stringValue(from value: JSONValue?) -> String {
        switch value {
        case .string(let string):
            return string
        case .int(let int):
            return String(int)
        case .double(let double):
            if double.rounded(.towardZero) == double {
                return String(Int(double))
            }
            return String(double)
        default:
            return ""
        }
    }

    private static func legacyPurchaseType(from raw: String) -> CreateAdDraft.PurchaseType? {
        switch raw {
        case "groceries":
            return .groceries
        case "medicine", "pharmacy":
            return .medicine
        case "clothing":
            return .clothing
        case "electronics":
            return .electronics
        case "home_goods", "homeGoods":
            return .homeGoods
        case "other":
            return .other
        default:
            return nil
        }
    }
}
