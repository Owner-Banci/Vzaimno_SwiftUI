import Foundation

enum OfferPricingMode: String, Codable, Equatable {
    case quickMinPrice = "quick_min_price"
    case counterPrice = "counter_price"
    case agreedPrice = "agreed_price"
}

enum AnnouncementOfferStatus: String, Codable, Equatable {
    case pending
    case accepted
    case rejected
    case withdrawn
    case expired
    case blocked
}

struct OfferPerformer: Equatable {
    let userID: String
    let displayName: String
    let city: String?
    let contact: String?
    let avatarURL: URL?

    var initials: String {
        let parts = displayName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first.map(String.init) }

        return parts.isEmpty ? "?" : parts.joined().uppercased()
    }

    var secondaryLine: String? {
        if let contact, !contact.isEmpty, contact != displayName {
            return contact
        }
        return city
    }
}

struct AnnouncementOffer: Identifiable, Equatable {
    let id: String
    let announcementID: String
    let performerID: String
    let message: String?
    let proposedPrice: Int?
    let agreedPrice: Int?
    let pricingMode: OfferPricingMode
    let minimumPriceAccepted: Bool
    let canReoffer: Bool
    let status: String
    let createdAt: Date
    let performer: OfferPerformer?
    let performerStats: ProfileStats?

    var formattedPrice: String? {
        let effectivePrice = agreedPrice ?? proposedPrice
        guard let effectivePrice else { return nil }
        return "\(effectivePrice.formatted(.number.grouping(.automatic))) ₽"
    }

    var statusValue: AnnouncementOfferStatus? {
        AnnouncementOfferStatus(rawValue: status)
    }

    var summaryText: String {
        if let message, !message.isEmpty {
            return message
        }
        if minimumPriceAccepted || pricingMode == .quickMinPrice {
            return "Быстрый отклик на минимальную цену"
        }
        if proposedPrice == nil && agreedPrice == nil {
            return "Быстрый отклик"
        }
        return "Отклик без сообщения"
    }
}

struct AcceptedOfferResult: Equatable {
    let threadID: String
    let offer: AnnouncementOffer
}

struct CreateOfferRequestDTO: Codable {
    let message: String?
    let proposed_price: Int?
    let pricing_mode: String?
    let agreed_price: Int?
    let minimum_price_accepted: Bool?
}

struct OfferPerformerProfileDTO: Codable {
    let user_id: String
    let display_name: String
    let city: String?
    let contact: String?
    let avatar_url: String?

    var domain: OfferPerformer {
        OfferPerformer(
            userID: user_id,
            displayName: normalizedOfferText(display_name) ?? "Пользователь",
            city: normalizedOfferText(city),
            contact: normalizedOfferText(contact),
            avatarURL: avatar_url.flatMap { AppURLResolver.resolveAPIURL(from: $0) }
        )
    }
}

struct OfferPerformerStatsDTO: Codable {
    let rating_avg: Double
    let rating_count: Int
    let completed_count: Int
    let cancelled_count: Int

    var domain: ProfileStats {
        ProfileStats(
            ratingAverage: rating_avg,
            ratingCount: rating_count,
            completedCount: completed_count,
            cancelledCount: cancelled_count
        )
    }
}

struct AnnouncementOfferDTO: Codable {
    let id: String
    let announcement_id: String
    let performer_id: String
    let message: String?
    let proposed_price: Int?
    let agreed_price: Int?
    let pricing_mode: String?
    let minimum_price_accepted: Bool?
    let can_reoffer: Bool?
    let status: String
    let created_at: String
    let performer_profile: OfferPerformerProfileDTO?
    let performer_stats: OfferPerformerStatsDTO?

    var domain: AnnouncementOffer {
        AnnouncementOffer(
            id: id,
            announcementID: announcement_id,
            performerID: performer_id,
            message: normalizedOfferText(message),
            proposedPrice: proposed_price,
            agreedPrice: agreed_price,
            pricingMode: OfferPricingMode(rawValue: pricing_mode ?? "") ?? .counterPrice,
            minimumPriceAccepted: minimum_price_accepted ?? false,
            canReoffer: can_reoffer ?? true,
            status: status,
            createdAt: ProfileDateParser.parse(created_at) ?? .now,
            performer: performer_profile?.domain,
            performerStats: performer_stats?.domain
        )
    }
}

struct AcceptOfferResponseDTO: Codable {
    let thread_id: String
    let offer: AnnouncementOfferDTO

    var domain: AcceptedOfferResult {
        AcceptedOfferResult(threadID: thread_id, offer: offer.domain)
    }
}

private func normalizedOfferText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
