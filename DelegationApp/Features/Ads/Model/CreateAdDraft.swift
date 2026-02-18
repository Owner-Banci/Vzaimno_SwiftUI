//
//  CreateAdDraft.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import Foundation

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
    @Published var startDate: Date = .now
    @Published var hasEndTime: Bool = false
    @Published var endDate: Date = .now

    @Published var cargoLength: String = ""
    @Published var cargoWidth: String = ""
    @Published var cargoHeight: String = ""

    @Published var floor: String = ""
    @Published var hasElevator: Bool = true
    @Published var needLoader: Bool = false

    // MARK: - Help fields
    @Published var helpAddress: String = ""

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

    // MARK: - Validation
    func validateForCurrentStep() -> (ok: Bool, message: String) {
        guard let category else { return (false, "Выберите категорию") }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (false, "Заполните название объявления")
        }
        switch category {
        case .delivery:
            if pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (false, "Укажите адрес забора")
            }
            if dropoffAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (false, "Укажите адрес доставки")
            }
        case .help:
            if helpAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (false, "Укажите адрес")
            }
        }
        return (true, "")
    }

    // MARK: - Mapping to request
    func toCreateRequest() -> CreateAnnouncementRequest {
        let iso = ISO8601DateFormatter()

        var data: [String: JSONValue] = [:]

        data["category"] = .string(category?.rawValue ?? "")
        data["budget"] = budget.isEmpty ? .null : .string(budget)

        data["contact_name"] = contactName.isEmpty ? .null : .string(contactName)
        data["contact_phone"] = contactPhone.isEmpty ? .null : .string(contactPhone)
        data["contact_method"] = .string(contactMethod.rawValue)

        data["audience"] = .string(audience.rawValue)

        data["notes"] = notes.isEmpty ? .null : .string(notes)
        data["media_local_identifiers"] = .array(mediaLocalIdentifiers.map { .string($0) })
        data["ai_hints"] = .array(aiHints.map { .string($0) })

        if let category {
            switch category {
            case .delivery:
                data["pickup_address"] = .string(pickupAddress)
                data["dropoff_address"] = .string(dropoffAddress)
                data["start_at"] = .string(iso.string(from: startDate))
                data["has_end_time"] = .bool(hasEndTime)
                data["end_at"] = hasEndTime ? .string(iso.string(from: endDate)) : .null

                data["cargo_length"] = cargoLength.isEmpty ? .null : .string(cargoLength)
                data["cargo_width"] = cargoWidth.isEmpty ? .null : .string(cargoWidth)
                data["cargo_height"] = cargoHeight.isEmpty ? .null : .string(cargoHeight)

                data["floor"] = floor.isEmpty ? .null : .string(floor)
                data["has_elevator"] = .bool(hasElevator)
                data["need_loader"] = .bool(needLoader)

            case .help:
                data["address"] = .string(helpAddress)
                data["start_at"] = .string(iso.string(from: startDate))
                data["has_end_time"] = .bool(hasEndTime)
                data["end_at"] = hasEndTime ? .string(iso.string(from: endDate)) : .null
            }
        }

        let categoryRaw = category?.rawValue ?? "unknown"
        return CreateAnnouncementRequest(
            category: categoryRaw,
            title: title,
            status: "active",
            data: data
        )
    }
}
