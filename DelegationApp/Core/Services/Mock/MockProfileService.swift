import Foundation

final class MockProfileService: ProfileService {
    private let mockReviews: [UserProfileReview] = [
        UserProfileReview(
            id: "maria-review",
            authorName: "Мария К.",
            stars: 5,
            text: "Отличный исполнитель! Всё сделал быстро и качественно. Рекомендую!",
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
            targetRole: .performer
        ),
        UserProfileReview(
            id: "dmitry-review",
            authorName: "Дмитрий С.",
            stars: 5,
            text: "Очень доволен! Приехал раньше срока, всё аккуратно.",
            createdAt: Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now,
            targetRole: .performer
        ),
    ]

    func fetchMeProfile(token: String) async throws -> UserProfile {
        UserProfile(
            userID: "mock-user-id",
            email: "alexey@example.com",
            phone: nil,
            displayName: "Алексей Иванов",
            bio: "Помогаю с доставкой и бытовыми задачами.",
            city: "Москва",
            preferredAddress: "Москва, ул. Тверская, 1",
            homeLocation: GeoPoint(latitude: 55.751244, longitude: 37.618423),
            stats: ProfileStats(
                ratingAverage: 4.9,
                ratingCount: 127,
                completedCount: 127,
                cancelledCount: 3
            ),
            createdAt: .now
        )
    }

    func updateMyProfile(token: String, fields: EditableProfileFields) async throws -> EditableProfileFields {
        fields
    }

    func fetchMyReviews(token: String, limit: Int, offset: Int) async throws -> [UserProfileReview] {
        let start = max(0, offset)
        let slice = mockReviews.dropFirst(start).prefix(max(0, limit))
        return Array(slice)
    }

    func fetchMyReviewsFeed(token: String, limit: Int, offset: Int, role: ReviewRole) async throws -> UserReviewFeed {
        let filtered = mockReviews.filter { $0.targetRole == role }
        let start = max(0, offset)
        let slice = Array(filtered.dropFirst(start).prefix(max(0, limit)))
        let average = slice.isEmpty ? 0 : Double(slice.map(\.stars).reduce(0, +)) / Double(slice.count)
        return UserReviewFeed(
            role: role,
            summary: ReviewSummary(average: average, count: filtered.count),
            reviews: slice
        )
    }

    func fetchReviewEligibility(token: String, announcementID: String) async throws -> ReviewEligibility {
        ReviewEligibility(
            announcementID: announcementID,
            announcementTitle: "Тестовое задание",
            threadID: "mock-thread",
            counterpartUserID: "mock-user",
            counterpartDisplayName: "Мария К.",
            counterpartRole: .performer,
            canSubmit: true,
            alreadySubmitted: false,
            message: nil
        )
    }

    func submitReview(token: String, announcementID: String, stars: Int, text: String) async throws { }
}
