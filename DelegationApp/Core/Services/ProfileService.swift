import Foundation

protocol ProfileService {
    func fetchMeProfile(token: String) async throws -> UserProfile
    func updateMyProfile(token: String, fields: EditableProfileFields) async throws -> EditableProfileFields
    func fetchMyReviews(token: String, limit: Int, offset: Int) async throws -> [UserProfileReview]
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
        let response: MyReviewsResponseDTO = try await api.request(.myReviews(limit: limit, offset: offset), token: token)
        return response.items.map(\.domain)
    }
}
