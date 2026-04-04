import Foundation

protocol ProfileService {
    func fetchMeProfile(token: String) async throws -> UserProfile
    func updateMyProfile(token: String, fields: EditableProfileFields) async throws -> EditableProfileFields
    func fetchMyReviews(token: String, limit: Int, offset: Int) async throws -> [UserProfileReview]
    func fetchMyReviewsFeed(token: String, limit: Int, offset: Int, role: ReviewRole) async throws -> UserReviewFeed
    func fetchReviewEligibility(token: String, announcementID: String) async throws -> ReviewEligibility
    func submitReview(token: String, announcementID: String, stars: Int, text: String) async throws
}

final class NetworkProfileService: ProfileService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func fetchMeProfile(token: String) async throws -> UserProfile {
        let response: MeProfileResponseDTO = try await api.request(.usersMe, token: token)
        return response.domain
    }

    func updateMyProfile(token: String, fields: EditableProfileFields) async throws -> EditableProfileFields {
        let request = UpdateMyProfileRequestDTO(fields: fields)
        let response: UserProfileSectionDTO = try await api.request(.updateMyProfile, body: request, token: token)
        return response.editableFields
    }

    func fetchMyReviews(token: String, limit: Int, offset: Int) async throws -> [UserProfileReview] {
        let response: MyReviewsResponseDTO = try await api.request(.myReviews(limit: limit, offset: offset, role: nil), token: token)
        return response.items.map(\.domain)
    }

    func fetchMyReviewsFeed(token: String, limit: Int, offset: Int, role: ReviewRole) async throws -> UserReviewFeed {
        let response: ReviewsFeedResponseDTO = try await api.request(
            .myReviews(limit: limit, offset: offset, role: role.rawValue),
            token: token
        )
        return response.domain(fallbackRole: role)
    }

    func fetchReviewEligibility(token: String, announcementID: String) async throws -> ReviewEligibility {
        let response: ReviewEligibilityDTO = try await api.request(.announcementReviewContext(announcementID: announcementID), token: token)
        return response.domain
    }

    func submitReview(token: String, announcementID: String, stars: Int, text: String) async throws {
        let request = SubmitReviewRequestDTO(stars: stars, text: normalized(text))
        let _: OperationStatusResponseDTO = try await api.request(
            .submitAnnouncementReview(announcementID: announcementID),
            body: request,
            token: token
        )
    }
}

private func normalized(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
