//
//  CreateAdDraft.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import Foundation
import YandexMapsMobile

@MainActor
final class CreateAdDraft: ObservableObject {

    enum Category: String, CaseIterable, Identifiable {
        case delivery = "delivery"
        case help = "help"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .delivery: return "Доставка и поручения"
            case .help: return "Помощь"
            }
        }

        var subtitle: String {
            switch self {
            case .delivery: return "Посылки, покупки, курьерские услуги"
            case .help: return "Помощь руками, поддержка, бытовые задачи"
            }
        }
    }

    enum ContactMethod: String, CaseIterable, Identifiable {
        case callsAndMessages = "calls_and_messages"
        case messagesOnly = "messages_only"
        case callsOnly = "calls_only"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .callsAndMessages: return "Звонки и сообщения"
            case .messagesOnly: return "Только сообщения"
            case .callsOnly: return "Только звонки"
            }
        }
    }

    enum Audience: String, CaseIterable, Identifiable {
        case individuals = "individuals"
        case business = "business"
        case both = "both"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .individuals: return "Частные лица"
            case .business: return "Бизнес"
            case .both: return "Частные лица и бизнес"
            }
        }
    }

    // MARK: - Common
    @Published var category: Category?
    @Published var title: String = ""
    @Published var budget: String = ""

    // MARK: - Delivery fields
    @Published var pickupAddress: String = ""
    @Published var dropoffAddress: String = ""
    @Published var pickupPoint: YMKPoint?
    @Published var dropoffPoint: YMKPoint?
    @Published var startDate: Date = Date().addingTimeInterval(10 * 60)
    @Published var hasEndTime: Bool = false
    @Published var endDate: Date = Date().addingTimeInterval(40 * 60)

    @Published var cargoLength: String = ""
    @Published var cargoWidth: String = ""
    @Published var cargoHeight: String = ""

    @Published var floor: String = ""
    @Published var hasElevator: Bool = true
    @Published var needLoader: Bool = false

    // MARK: - Help fields
    @Published var helpAddress: String = ""
    @Published var helpPoint: YMKPoint?

    // MARK: - Notes + future hooks
    @Published var notes: String = ""
    /// Заглушка под будущую загрузку фото/видео (позже: PhotosPicker / upload).
    @Published var mediaLocalIdentifiers: [String] = []
    /// Заглушка под будущую обработку текста/фото моделями.
    @Published var aiHints: [String] = []

    // MARK: - Contacts
    @Published var contactName: String = ""
    @Published var contactPhone: String = ""
    @Published var contactMethod: ContactMethod = .callsAndMessages

    // MARK: - Audience
    @Published var audience: Audience = .both

    private var pickupAddressSnapshot: String?
    private var dropoffAddressSnapshot: String?
    private var helpAddressSnapshot: String?

    // MARK: - Validation
    func validateMainStepSync() -> String? {
        guard let category else { return "Выберите категорию" }

        if let e = AdValidators.validateTitle(title) { return e }
        if let e = AdValidators.validateBudget(budget) { return e }
        if let e = AdValidators.validateTimeWindow(
            startDate: startDate,
            hasEndTime: hasEndTime,
            endDate: endDate
        ) { return e }

        switch category {
        case .delivery:
            if let e = AdValidators.validateAddress(pickupAddress, fieldName: "Адрес забора") { return e }
            if let e = AdValidators.validateAddress(dropoffAddress, fieldName: "Адрес доставки") { return e }
            if let e = AdValidators.validateDifferentAddresses(pickupAddress, dropoffAddress) { return e }
            if let e = AdValidators.validateDimension(cargoLength, fieldName: "Длина", max: 85) { return e }
            if let e = AdValidators.validateDimension(cargoWidth, fieldName: "Ширина", max: 57) { return e }
            if let e = AdValidators.validateDimension(cargoHeight, fieldName: "Высота", max: 57) { return e }
            if let e = AdValidators.validateFloor(floor) { return e }
        case .help:
            if let e = AdValidators.validateAddress(helpAddress, fieldName: "Адрес") { return e }
        }

        return nil
    }

    func validateAndGeocodeMainStep(searchService: AddressSearchService) async -> String? {
        if let e = validateMainStepSync() { return e }

        guard let category else { return "Выберите категорию" }

        switch category {
        case .delivery:
            let pickupNormalized = AdValidators.normalizedAddress(pickupAddress)
            let dropoffNormalized = AdValidators.normalizedAddress(dropoffAddress)

            if pickupAddressSnapshot != pickupNormalized {
                pickupPoint = await searchService.searchAddress(pickupNormalized)
                pickupAddressSnapshot = pickupPoint == nil ? nil : pickupNormalized
            }
            guard pickupPoint != nil else {
                return "Адрес забора не найден. Уточните адрес"
            }

            if dropoffAddressSnapshot != dropoffNormalized {
                dropoffPoint = await searchService.searchAddress(dropoffNormalized)
                dropoffAddressSnapshot = dropoffPoint == nil ? nil : dropoffNormalized
            }
            guard dropoffPoint != nil else {
                return "Адрес доставки не найден. Уточните адрес"
            }

        case .help:
            let helpNormalized = AdValidators.normalizedAddress(helpAddress)
            if helpAddressSnapshot != helpNormalized {
                helpPoint = await searchService.searchAddress(helpNormalized)
                helpAddressSnapshot = helpPoint == nil ? nil : helpNormalized
            }
            guard helpPoint != nil else {
                return "Адрес не найден. Уточните адрес"
            }
        }

        return nil
    }

    func validateContactStep() -> String? {
        let phone = AdValidators.validateOptionalPhone(contactPhone)
        if let e = phone.error { return e }
        contactPhone = phone.normalized ?? ""
        contactName = AdValidators.trimmed(contactName)
        return nil
    }

    func validateForSubmit(searchService: AddressSearchService) async -> String? {
        if let e = await validateAndGeocodeMainStep(searchService: searchService) { return e }
        if let e = validateContactStep() { return e }
        return nil
    }

    // MARK: - Mapping to request
    func toCreateRequest() -> CreateAnnouncementRequest {
        let iso = ISO8601DateFormatter()

        var data: [String: JSONValue] = [:]
        let titleTrimmed = AdValidators.trimmed(title)

        data["category"] = .string(category?.rawValue ?? "")
        data["budget"] = jsonOptionalDecimal(budget)

        let contactNameTrimmed = AdValidators.trimmed(contactName)
        data["contact_name"] = contactNameTrimmed.isEmpty ? .null : .string(contactNameTrimmed)
        if let phoneNormalized = AdValidators.validateOptionalPhone(contactPhone).normalized {
            data["contact_phone"] = .string(phoneNormalized)
        } else {
            data["contact_phone"] = .null
        }
        data["contact_method"] = .string(contactMethod.rawValue)

        data["audience"] = .string(audience.rawValue)

        let notesTrimmed = AdValidators.trimmed(notes)
        data["notes"] = notesTrimmed.isEmpty ? .null : .string(notesTrimmed)
        data["media_local_identifiers"] = .array(mediaLocalIdentifiers.map { .string($0) })
        data["ai_hints"] = .array(aiHints.map { .string($0) })

        if let category {
            switch category {
            case .delivery:
                let pickup = AdValidators.normalizedAddress(pickupAddress)
                let dropoff = AdValidators.normalizedAddress(dropoffAddress)

                data["pickup_address"] = .string(pickup)
                data["dropoff_address"] = .string(dropoff)
                data["start_at"] = .string(iso.string(from: startDate))
                data["has_end_time"] = .bool(hasEndTime)
                data["end_at"] = hasEndTime ? .string(iso.string(from: endDate)) : .null

                data["cargo_length"] = jsonOptionalDecimal(cargoLength)
                data["cargo_width"] = jsonOptionalDecimal(cargoWidth)
                data["cargo_height"] = jsonOptionalDecimal(cargoHeight)

                data["floor"] = jsonOptionalInt(floor)
                data["has_elevator"] = .bool(hasElevator)
                data["need_loader"] = .bool(needLoader)

                if let pickupPoint {
                    let jsonPoint = Self.jsonPoint(pickupPoint)
                    data["pickup_point"] = jsonPoint
                    data["point"] = jsonPoint
                }
                if let dropoffPoint {
                    data["dropoff_point"] = Self.jsonPoint(dropoffPoint)
                }

            case .help:
                let address = AdValidators.normalizedAddress(helpAddress)
                data["address"] = .string(address)
                data["start_at"] = .string(iso.string(from: startDate))
                data["has_end_time"] = .bool(hasEndTime)
                data["end_at"] = hasEndTime ? .string(iso.string(from: endDate)) : .null

                if let helpPoint {
                    let jsonPoint = Self.jsonPoint(helpPoint)
                    data["help_point"] = jsonPoint
                    data["point"] = jsonPoint
                }
            }
        }

        let categoryRaw = category?.rawValue ?? "unknown"
        return CreateAnnouncementRequest(
            category: categoryRaw,
            title: titleTrimmed,
            status: "active",
            data: data
        )
    }

    private func jsonOptionalDecimal(_ raw: String) -> JSONValue {
        guard let value = AdValidators.parseDecimal(raw) else { return .null }
        return .double(value)
    }

    private func jsonOptionalInt(_ raw: String) -> JSONValue {
        let trimmed = AdValidators.trimmed(raw)
        guard let value = Int(trimmed) else { return .null }
        return .int(value)
    }

    private static func jsonPoint(_ point: YMKPoint) -> JSONValue {
        .object([
            "lat": .double(point.latitude),
            "lon": .double(point.longitude),
        ])
    }
}
