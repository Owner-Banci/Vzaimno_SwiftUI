import Foundation

struct GeoPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct ProfileStats: Equatable {
    let ratingAverage: Double
    let ratingCount: Int
    let completedCount: Int
    let cancelledCount: Int
}

struct EditableProfileFields: Equatable {
    let displayName: String
    let bio: String
    let city: String
    let preferredAddress: String
    let homeLocation: GeoPoint?
}

struct UserProfile: Equatable {
    let userID: String
    let email: String?
    let phone: String?
    let displayName: String?
    let bio: String
    let city: String
    let preferredAddress: String
    let homeLocation: GeoPoint?
    let stats: ProfileStats
    let createdAt: Date?

    var resolvedDisplayName: String {
        nonEmpty(displayName) ?? primaryContact ?? "Пользователь"
    }

    var primaryContact: String? {
        nonEmpty(phone) ?? nonEmpty(email)
    }

    var contactValue: String {
        primaryContact ?? "Контакт не указан"
    }

    var contactTitle: String {
        nonEmpty(phone) != nil ? "Телефон" : "Email"
    }

    var contactCaption: String {
        if nonEmpty(phone) != nil {
            return "Телефон привязан к аккаунту"
        }
        if nonEmpty(email) != nil {
            return "Email привязан к аккаунту"
        }
        return "Контакт привязан к аккаунту"
    }

    var editableFields: EditableProfileFields {
        EditableProfileFields(
            displayName: nonEmpty(displayName) ?? primaryContact ?? "",
            bio: bio,
            city: city,
            preferredAddress: preferredAddress,
            homeLocation: homeLocation
        )
    }

    func applying(_ fields: EditableProfileFields) -> UserProfile {
        UserProfile(
            userID: userID,
            email: email,
            phone: phone,
            displayName: nonEmpty(fields.displayName),
            bio: fields.bio,
            city: fields.city,
            preferredAddress: fields.preferredAddress,
            homeLocation: fields.homeLocation,
            stats: stats,
            createdAt: createdAt
        )
    }
}

struct UserProfileReview: Identifiable, Equatable {
    let id: String
    let authorName: String
    let stars: Int
    let text: String
    let createdAt: Date

    var authorInitials: String {
        let parts = authorName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first.map(String.init) }

        if parts.isEmpty {
            return "?"
        }

        return parts.joined().uppercased()
    }

    var relativeCreatedAt: String {
        ProfileRelativeDateFormatter.shared.localizedString(for: createdAt, relativeTo: .now)
    }
}

enum ProfileDateParser {
    private static let internetFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parse(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        if let date = fractionalFormatter.date(from: rawValue) {
            return date
        }

        return internetFormatter.date(from: rawValue)
    }
}

private enum ProfileRelativeDateFormatter {
    static let shared: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

private func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
