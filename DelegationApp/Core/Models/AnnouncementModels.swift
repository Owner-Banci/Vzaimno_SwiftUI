//
//  AnnouncementModels.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import CoreLocation
import Foundation

// MARK: - Network models

enum AppURLResolver {
    static func resolveAPIURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        let normalizedPath = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else { return nil }

        return normalizedPath
            .split(separator: "/")
            .reduce(AppConfig.apiBaseURL) { partialURL, component in
                partialURL.appendingPathComponent(String(component))
            }
    }
}

struct AnnouncementDTO: Codable, Identifiable {
    let id: String
    let user_id: String
    let category: String
    let title: String
    let status: String
    let data: [String: JSONValue]
    let created_at: String
    let media: [JSONValue]?

    init(
        id: String,
        user_id: String,
        category: String,
        title: String,
        status: String,
        data: [String: JSONValue],
        created_at: String,
        media: [JSONValue]? = nil
    ) {
        self.id = id
        self.user_id = user_id
        self.category = category
        self.title = title
        self.status = status
        self.data = data
        self.created_at = created_at
        self.media = media
    }
}

struct CreateAnnouncementRequest: Codable {
    let category: String
    let title: String
    let status: String
    let data: [String: JSONValue]

    init(category: String, title: String, status: String = "active", data: [String: JSONValue]) {
        self.category = category
        self.title = title
        self.status = status
        self.data = data
    }
}


//------------------------------

struct MediaModerationResponse: Codable {
    let announcement: AnnouncementDTO
    let max_nsfw: Double
    let decision: String
    let can_appeal: Bool
    let message: String
}

struct AppealRequest: Codable {
    let reason: String?
}

extension AnnouncementDTO {
    var createdAtDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: created_at) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: created_at) ?? .distantPast
    }

    var imageURLs: [URL] {
        var seen: Set<String> = []
        return rawMediaValues
            .compactMap(Self.resolveMediaURL(from:))
            .filter { seen.insert($0.absoluteString).inserted }
    }

    var previewImageURL: URL? {
        imageURLs.first
    }

    var hasAttachedMedia: Bool {
        !imageURLs.isEmpty
    }

    var offersCount: Int {
        intValue(for: "offers_count") ?? 0
    }

    var budgetValue: Int? {
        taskIntValue(
            paths: [["task", "budget", "amount"]],
            legacyKeys: ["budget"]
        ) ?? intValue(for: "budget")
    }

    var budgetMinValue: Int? {
        taskIntValue(
            paths: [["task", "budget", "min"]],
            legacyKeys: ["budget_min"]
        ) ?? intValue(for: "budget_min")
    }

    var budgetMaxValue: Int? {
        taskIntValue(
            paths: [["task", "budget", "max"]],
            legacyKeys: ["budget_max"]
        ) ?? intValue(for: "budget_max")
    }

    var formattedBudgetText: String? {
        if let budgetMinValue, let budgetMaxValue {
            if budgetMinValue == budgetMaxValue {
                return Self.formatCurrency(budgetMinValue)
            }
            return "\(Self.formatRawCurrency(budgetMinValue))–\(Self.formatRawCurrency(budgetMaxValue)) ₽"
        }

        if let budgetMinValue {
            return "от \(Self.formatRawCurrency(budgetMinValue)) ₽"
        }

        if let budgetMaxValue {
            return "до \(Self.formatRawCurrency(budgetMaxValue)) ₽"
        }

        if let budget = intValue(for: "budget") {
            return Self.formatCurrency(budget)
        }

        if let budgetText = data["budget"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !budgetText.isEmpty {
            return "\(budgetText) ₽"
        }

        return nil
    }

    var moderationCanAppeal: Bool {
        guard
            let mod = data["moderation"]?.objectValue,
            let img = mod["image"]?.objectValue,
            let can = img["can_appeal"]?.boolValue
        else { return false }
        return can
    }

    private var rawMediaValues: [JSONValue] {
        var values: [JSONValue] = media ?? []

        for key in ["media", "images", "photos"] {
            guard let raw = data[key] else { continue }

            if let array = raw.arrayValue {
                values.append(contentsOf: array)
            } else {
                values.append(raw)
            }
        }

        return values
    }

    private static func resolveMediaURL(from value: JSONValue) -> URL? {
        switch value {
        case .string(let string):
            return AppURLResolver.resolveAPIURL(from: string)

        case .object(let object):
            let preferredKeys = [
                "preview_url",
                "previewUrl",
                "thumbnail_url",
                "thumbnailUrl",
                "url",
                "image_url",
                "imageUrl",
                "file_url",
                "fileUrl",
                "path",
            ]

            for key in preferredKeys {
                if let raw = object[key]?.stringValue, let url = AppURLResolver.resolveAPIURL(from: raw) {
                    return url
                }
            }

            if let nested = object["file"] {
                return resolveMediaURL(from: nested)
            }

            return nil

        default:
            return nil
        }
    }

    private func intValue(for key: String) -> Int? {
        guard let value = data[key] else { return nil }
        return Self.intValue(from: value)
    }

    private static func intValue(from value: JSONValue) -> Int? {
        switch value {
        case .int(let intValue):
            return intValue
        case .double(let doubleValue):
            return Int(doubleValue)
        case .string(let stringValue):
            let normalized = stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            guard let parsed = Double(normalized) else { return nil }
            return Int(parsed)
        default:
            return nil
        }
    }

    private static func formatCurrency(_ value: Int) -> String {
        "\(formatRawCurrency(value)) ₽"
    }

    private static func formatRawCurrency(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }
}

struct AnnouncementStructuredData: Equatable {
    enum ActionType: String, CaseIterable, Hashable {
        case pickup
        case buy
        case carry
        case ride
        case proHelp = "pro_help"
        case other

        var title: String {
            switch self {
            case .pickup: return "Забрать"
            case .buy: return "Купить"
            case .carry: return "Перенести"
            case .ride: return "Подвезти"
            case .proHelp: return "Помощь от профи"
            case .other: return "Другое"
            }
        }
    }

    enum ResolvedCategory: String, CaseIterable, Hashable {
        case pickupPoint = "pickup_point"
        case handoff
        case buy
        case carry
        case ride
        case proHelp = "pro_help"
        case other
    }

    enum SourceKind: String, CaseIterable, Hashable {
        case person
        case pickupPoint = "pickup_point"
        case venue
        case address
        case office
        case other

        var title: String {
            switch self {
            case .person: return "У человека"
            case .pickupPoint: return "Из ПВЗ"
            case .venue: return "Из заведения"
            case .address: return "С адреса"
            case .office: return "Из офиса"
            case .other: return "Другое"
            }
        }
    }

    enum DestinationKind: String, CaseIterable, Hashable {
        case person
        case address
        case office
        case entrance
        case metro
        case other

        var title: String {
            switch self {
            case .person: return "Человеку"
            case .address: return "По адресу"
            case .office: return "В офис"
            case .entrance: return "До подъезда"
            case .metro: return "К метро"
            case .other: return "Другое"
            }
        }
    }

    enum Urgency: String, CaseIterable, Hashable {
        case now
        case today
        case scheduled
        case flexible

        var title: String {
            switch self {
            case .now: return "Сейчас"
            case .today: return "Сегодня"
            case .scheduled: return "Ко времени"
            case .flexible: return "Не срочно"
            }
        }
    }

    enum WeightCategory: String, CaseIterable, Hashable {
        case upTo1kg = "up_to_1kg"
        case upTo3kg = "up_to_3kg"
        case upTo7kg = "up_to_7kg"
        case upTo15kg = "up_to_15kg"
        case over15kg = "over_15kg"

        var title: String {
            switch self {
            case .upTo1kg: return "До 1 кг"
            case .upTo3kg: return "До 3 кг"
            case .upTo7kg: return "До 7 кг"
            case .upTo15kg: return "До 15 кг"
            case .over15kg: return "Тяжелее"
            }
        }
    }

    enum SizeCategory: String, CaseIterable, Hashable {
        case pocket
        case hand
        case backpack
        case trunk
        case bulky

        var title: String {
            switch self {
            case .pocket: return "Карман"
            case .hand: return "В руку"
            case .backpack: return "В рюкзак"
            case .trunk: return "В багажник"
            case .bulky: return "Крупное"
            }
        }
    }

    let actionType: ActionType?
    let resolvedCategory: ResolvedCategory?
    let itemType: String?
    let purchaseType: String?
    let helpType: String?
    let sourceKind: SourceKind?
    let destinationKind: DestinationKind?
    let urgency: Urgency?
    let requiresVehicle: Bool
    let needsTrunk: Bool
    let requiresCarefulHandling: Bool
    let needsLoader: Bool
    let requiresLiftToFloor: Bool
    let hasElevator: Bool
    let waitOnSite: Bool
    let contactless: Bool
    let requiresReceipt: Bool
    let requiresConfirmationCode: Bool
    let callBeforeArrival: Bool
    let photoReportRequired: Bool
    let weightCategory: WeightCategory?
    let sizeCategory: SizeCategory?
    let estimatedTaskMinutes: Int?
    let waitingMinutes: Int?
    let budgetMin: Int?
    let budgetMax: Int?
    let sourceAddress: String?
    let destinationAddress: String?
    let taskBrief: String?
    let notes: String?
}

extension AnnouncementDTO {
    var structuredData: AnnouncementStructuredData {
        AnnouncementStructuredData(
            actionType: taskStringValue(
                paths: [
                    ["task", "builder", "action_type"],
                    ["task", "builder", "user_action_type"],
                ],
                legacyKeys: ["user_action_type", "action_type"]
            )
                .flatMap(AnnouncementStructuredData.ActionType.init(rawValue:)),
            resolvedCategory: taskStringValue(
                paths: [["task", "builder", "resolved_category"]],
                legacyKeys: ["resolved_category"]
            )
                .flatMap(AnnouncementStructuredData.ResolvedCategory.init(rawValue:)),
            itemType: taskStringValue(
                paths: [["task", "builder", "item_type"]],
                legacyKeys: ["item_type"]
            ),
            purchaseType: taskStringValue(
                paths: [["task", "builder", "purchase_type"]],
                legacyKeys: ["purchase_type"]
            ),
            helpType: taskStringValue(
                paths: [["task", "builder", "help_type"]],
                legacyKeys: ["help_type"]
            ),
            sourceKind: normalizedSourceKind,
            destinationKind: taskStringValue(
                paths: [["task", "builder", "destination_kind"]],
                legacyKeys: ["destination_kind"]
            )
                .flatMap(AnnouncementStructuredData.DestinationKind.init(rawValue:)),
            urgency: taskStringValue(
                paths: [["task", "builder", "urgency"]],
                legacyKeys: ["urgency"]
            )
                .flatMap(AnnouncementStructuredData.Urgency.init(rawValue:)),
            requiresVehicle: taskBoolValue(
                paths: [["task", "attributes", "requires_vehicle"]],
                legacyKeys: ["requires_vehicle"]
            ) ?? boolValue(for: ["requires_vehicle"]),
            needsTrunk: taskBoolValue(
                paths: [["task", "attributes", "needs_trunk"]],
                legacyKeys: ["needs_trunk"]
            ) ?? boolValue(for: ["needs_trunk"]),
            requiresCarefulHandling: taskBoolValue(
                paths: [["task", "attributes", "requires_careful_handling"]],
                legacyKeys: ["requires_careful_handling"]
            ) ?? boolValue(for: ["requires_careful_handling"]),
            needsLoader: taskBoolValue(
                paths: [["task", "attributes", "needs_loader"]],
                legacyKeys: ["needs_loader", "need_loader"]
            ) ?? boolValue(for: ["needs_loader", "need_loader"]),
            requiresLiftToFloor: taskBoolValue(
                paths: [["task", "attributes", "requires_lift_to_floor"]],
                legacyKeys: ["requires_lift_to_floor"]
            ) ?? boolValue(for: ["requires_lift_to_floor"]),
            hasElevator: taskBoolValue(
                paths: [["task", "attributes", "has_elevator"]],
                legacyKeys: ["has_elevator"]
            ) ?? boolValue(for: ["has_elevator"]),
            waitOnSite: taskBoolValue(
                paths: [["task", "attributes", "wait_on_site"]],
                legacyKeys: ["wait_on_site"]
            ) ?? boolValue(for: ["wait_on_site"]),
            contactless: taskBoolValue(
                paths: [["task", "attributes", "contactless"]],
                legacyKeys: ["contactless"]
            ) ?? boolValue(for: ["contactless"]),
            requiresReceipt: taskBoolValue(
                paths: [["task", "attributes", "requires_receipt"]],
                legacyKeys: ["requires_receipt"]
            ) ?? boolValue(for: ["requires_receipt"]),
            requiresConfirmationCode: taskBoolValue(
                paths: [["task", "attributes", "requires_confirmation_code"]],
                legacyKeys: ["requires_confirmation_code"]
            ) ?? boolValue(for: ["requires_confirmation_code"]),
            callBeforeArrival: taskBoolValue(
                paths: [["task", "attributes", "call_before_arrival"]],
                legacyKeys: ["call_before_arrival"]
            ) ?? boolValue(for: ["call_before_arrival"]),
            photoReportRequired: taskBoolValue(
                paths: [["task", "attributes", "photo_report_required"]],
                legacyKeys: ["photo_report_required"]
            ) ?? boolValue(for: ["photo_report_required"]),
            weightCategory: taskStringValue(
                paths: [["task", "attributes", "weight_category"]],
                legacyKeys: ["weight_category"]
            )
                .flatMap(AnnouncementStructuredData.WeightCategory.init(rawValue:)),
            sizeCategory: taskStringValue(
                paths: [["task", "attributes", "size_category"]],
                legacyKeys: ["size_category"]
            )
                .flatMap(AnnouncementStructuredData.SizeCategory.init(rawValue:)),
            estimatedTaskMinutes: taskIntValue(
                paths: [["task", "attributes", "estimated_task_minutes"]],
                legacyKeys: ["estimated_task_minutes"]
            ) ?? intValue(forAny: ["estimated_task_minutes"]),
            waitingMinutes: taskIntValue(
                paths: [["task", "attributes", "waiting_minutes"]],
                legacyKeys: ["waiting_minutes"]
            ) ?? intValue(forAny: ["waiting_minutes"]),
            budgetMin: budgetMinValue,
            budgetMax: budgetMaxValue ?? budgetValue,
            sourceAddress: primarySourceAddress,
            destinationAddress: primaryDestinationAddress,
            taskBrief: taskStringValue(
                paths: [["task", "builder", "task_brief"]],
                legacyKeys: ["task_brief"]
            ),
            notes: taskStringValue(
                paths: [["task", "builder", "notes"]],
                legacyKeys: ["notes"]
            )
        )
    }

    var primarySourceAddress: String? {
        taskStringValue(
            paths: [
                ["task", "route", "source", "address"],
                ["task", "route", "start", "address"],
            ],
            legacyKeys: ["source_address", "pickup_address", "address"]
        )
    }

    var primaryDestinationAddress: String? {
        taskStringValue(
            paths: [
                ["task", "route", "destination", "address"],
                ["task", "route", "end", "address"],
            ],
            legacyKeys: ["destination_address", "dropoff_address"]
        )
    }

    var detailsDescriptionText: String? {
        if let notes = structuredData.notes {
            return notes
        }

        return taskStringValue(
            paths: [["task", "search", "generated_description"]],
            legacyKeys: ["generated_description"]
        )
    }

    var mapCoordinate: CLLocationCoordinate2D? {
        taskPointCoordinate(
            paths: [
                ["task", "route", "source", "point"],
                ["task", "route", "start", "point"],
            ],
            legacyKeys: ["point", "pickup_point", "help_point", "source_point"]
        )
            ?? taskPointCoordinate(
                paths: [
                    ["task", "route", "destination", "point"],
                    ["task", "route", "end", "point"],
                ],
                legacyKeys: ["dropoff_point", "destination_point"]
            )
    }

    var sourceCoordinate: CLLocationCoordinate2D? {
        taskPointCoordinate(
            paths: [
                ["task", "route", "source", "point"],
                ["task", "route", "start", "point"],
            ],
            legacyKeys: ["pickup_point", "help_point", "point", "source_point"]
        )
    }

    var destinationCoordinate: CLLocationCoordinate2D? {
        taskPointCoordinate(
            paths: [
                ["task", "route", "destination", "point"],
                ["task", "route", "end", "point"],
            ],
            legacyKeys: ["dropoff_point", "destination_point"]
        )
    }

    var searchableText: String {
        let structured = structuredData
        var parts: [String] = [
            title,
            structured.actionType?.title,
            structured.sourceKind?.title,
            structured.destinationKind?.title,
            structured.urgency?.title,
            structured.itemType,
            structured.purchaseType,
            structured.helpType,
            structured.taskBrief,
            structured.notes,
            primarySourceAddress,
            primaryDestinationAddress,
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }

        if let generatedTags = data["generated_tags"]?.arrayValue {
            parts.append(contentsOf: generatedTags.compactMap(\.stringValue))
        }
        if let hints = data["ai_hints"]?.arrayValue {
            parts.append(contentsOf: hints.compactMap(\.stringValue))
        }

        return parts
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    var shortStructuredSubtitle: String {
        let structured = structuredData
        var parts: [String] = []

        if let action = structured.actionType?.title {
            parts.append(action)
        }

        if let object = structured.helpType ?? structured.purchaseType ?? structured.itemType {
            parts.append(Self.humanize(rawValue: object))
        }

        if let source = primarySourceAddress, !source.isEmpty {
            parts.append(source)
        } else if let sourceTitle = structured.sourceKind?.title {
            parts.append(sourceTitle)
        }

        return parts.prefix(3).joined(separator: " • ")
    }

    var structuredBadges: [String] {
        let structured = structuredData
        var badges: [String] = []

        if structured.actionType == .proHelp { badges.append("Профи") }
        if structured.requiresVehicle { badges.append("Машина") }
        if structured.needsTrunk { badges.append("Багажник") }
        if structured.requiresCarefulHandling { badges.append("Аккуратно") }
        if structured.needsLoader { badges.append("Грузчик") }
        if structured.requiresLiftToFloor { badges.append("Подъём") }
        if structured.urgency == .now || structured.urgency == .today { badges.append("Срочно") }
        if structured.sourceKind == .pickupPoint { badges.append("ПВЗ") }
        if structured.purchaseType == "groceries" || structured.itemType == "groceries" { badges.append("Продукты") }
        if let size = structured.sizeCategory?.title, badges.count < 4 { badges.append(size) }
        if let weight = structured.weightCategory?.title, badges.count < 4 { badges.append(weight) }

        return Array(badges.prefix(4))
    }

    private var normalizedSourceKind: AnnouncementStructuredData.SourceKind? {
        guard let raw = taskStringValue(
            paths: [["task", "builder", "source_kind"]],
            legacyKeys: ["source_kind"]
        ) else { return nil }
        switch raw {
        case "store", "pharmacy", "venue":
            return .venue
        case "pickupPoint":
            return .pickupPoint
        default:
            return AnnouncementStructuredData.SourceKind(rawValue: raw)
        }
    }

    private func rawValue(for keys: [String]) -> String? {
        for key in keys {
            guard let value = data[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            return value
        }
        return nil
    }

    private func boolValue(for keys: [String]) -> Bool {
        for key in keys {
            if let value = data[key]?.boolValue {
                return value
            }
        }
        return false
    }

    private func intValue(forAny keys: [String]) -> Int? {
        for key in keys {
            if let value = data[key] {
                return Self.intValue(from: value)
            }
        }
        return nil
    }

    private func taskPointCoordinate(
        paths: [[String]],
        legacyKeys: [String]
    ) -> CLLocationCoordinate2D? {
        for path in paths {
            guard let object = taskValue(at: path)?.objectValue,
                  let lat = object["lat"]?.doubleValue,
                  let lon = object["lon"]?.doubleValue,
                  (-90...90).contains(lat),
                  (-180...180).contains(lon) else { continue }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        return pointCoordinate(for: legacyKeys)
    }

    private func pointCoordinate(for keys: [String]) -> CLLocationCoordinate2D? {
        for key in keys {
            guard let object = data[key]?.objectValue,
                  let lat = object["lat"]?.doubleValue,
                  let lon = object["lon"]?.doubleValue,
                  (-90...90).contains(lat),
                  (-180...180).contains(lon) else { continue }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }

    private static func humanize(rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized(with: .current)
    }
}
