import Foundation

struct GeoPointDTO: Codable {
    let lat: Double
    let lon: Double

    var domain: GeoPoint {
        GeoPoint(latitude: lat, longitude: lon)
    }

    init(_ point: GeoPoint) {
        self.lat = point.latitude
        self.lon = point.longitude
    }
}

struct CurrentUserProfileDTO: Codable {
    let id: String
    let email: String?
    let phone: String?
    let created_at: String?
}

struct UserProfileSectionDTO: Codable {
    let display_name: String?
    let bio: String?
    let city: String?
    let preferred_address: String?
    let home_location: GeoPointDTO?

    var editableFields: EditableProfileFields {
        EditableProfileFields(
            displayName: display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            bio: bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            city: city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            preferredAddress: preferred_address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            homeLocation: home_location?.domain
        )
    }
}

struct UserStatsDTO: Codable {
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

struct MeProfileResponseDTO: Codable {
    let user: CurrentUserProfileDTO
    let profile: UserProfileSectionDTO
    let stats: UserStatsDTO

    var domain: UserProfile {
        let editableFields = profile.editableFields
        return UserProfile(
            userID: user.id,
            email: normalized(user.email),
            phone: normalized(user.phone),
            displayName: normalized(editableFields.displayName),
            bio: editableFields.bio,
            city: editableFields.city,
            preferredAddress: editableFields.preferredAddress,
            homeLocation: editableFields.homeLocation,
            stats: stats.domain,
            createdAt: ProfileDateParser.parse(user.created_at)
        )
    }
}

struct UpdateMyProfileRequestDTO: Codable {
    let display_name: String
    let bio: String?
    let city: String?
    let preferred_address: String?
    let home_location: GeoPointDTO?

    init(fields: EditableProfileFields) {
        self.display_name = fields.displayName
        self.bio = normalized(fields.bio)
        self.city = normalized(fields.city)
        self.preferred_address = normalized(fields.preferredAddress)
        self.home_location = nil
    }
}

struct MyReviewsResponseDTO: Codable {
    let items: [UserProfileReviewDTO]
}

struct UserProfileReviewDTO: Codable {
    let from_user_display_name: String?
    let stars: Int
    let text: String?
    let created_at: String

    var domain: UserProfileReview {
        let safeAuthor = normalized(from_user_display_name) ?? "Пользователь"
        let safeText = normalized(text) ?? "Без текста"
        let createdAt = ProfileDateParser.parse(created_at) ?? .now
        let rawID = "\(safeAuthor)|\(created_at)|\(safeText)|\(stars)"

        return UserProfileReview(
            id: rawID,
            authorName: safeAuthor,
            stars: max(0, min(5, stars)),
            text: safeText,
            createdAt: createdAt
        )
    }
}

struct DeviceRegistrationRequestDTO: Codable {
    let device_id: String
    let platform: String
    let push_token: String?
    let locale: String?
    let timezone: String?
    let device_name: String?
}

struct UnregisterDeviceRequestDTO: Codable {
    let device_id: String
    let push_token: String?
}

struct OperationStatusResponseDTO: Decodable {
    let ok: Bool
}

private func normalized(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
