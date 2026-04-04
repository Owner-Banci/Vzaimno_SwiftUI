import Foundation

struct DeleteOKResponse: Decodable {
    let ok: Bool
}

struct ExecutionStageUpdateRequestDTO: Codable {
    let stage: String
}

protocol AnnouncementService {
    func createAnnouncement(token: String, request: CreateAnnouncementRequest) async throws -> AnnouncementDTO
    func myAnnouncements(token: String) async throws -> [AnnouncementDTO]
    func publicAnnouncements() async throws -> [AnnouncementDTO]
    func fetchAnnouncement(token: String, announcementId: String) async throws -> AnnouncementDTO

    func uploadAnnouncementMedia(token: String, announcementId: String, images: [Data]) async throws -> AnnouncementDTO

    func archiveAnnouncement(token: String, announcementId: String) async throws -> AnnouncementDTO
    func deleteAnnouncement(token: String, announcementId: String) async throws -> Bool

    // оставляем на будущее
    func appealAnnouncement(token: String, announcementId: String, reason: String?) async throws -> AnnouncementDTO

    func createOffer(
        token: String,
        announcementId: String,
        message: String?,
        proposedPrice: Int?,
        pricingMode: OfferPricingMode,
        agreedPrice: Int?,
        minimumPriceAccepted: Bool
    ) async throws -> AnnouncementOffer
    func fetchOffers(token: String, announcementId: String) async throws -> [AnnouncementOffer]
    func acceptOffer(token: String, announcementId: String, offerId: String) async throws -> AcceptedOfferResult
    func rejectOffer(token: String, announcementId: String, offerId: String) async throws
    func updateExecutionStage(token: String, announcementId: String, stage: String) async throws -> AnnouncementDTO
}

final class NetworkAnnouncementService: AnnouncementService {
    private let api: APIClient
    init(api: APIClient = APIClient()) { self.api = api }

    func createAnnouncement(token: String, request: CreateAnnouncementRequest) async throws -> AnnouncementDTO {
        try await api.request(.createAnnouncement, body: request, token: token)
    }

    func myAnnouncements(token: String) async throws -> [AnnouncementDTO] {
        try await api.request(.myAnnouncements, token: token)
    }

    func publicAnnouncements() async throws -> [AnnouncementDTO] {
        try await api.request(.publicAnnouncements)
    }

    func fetchAnnouncement(token: String, announcementId: String) async throws -> AnnouncementDTO {
        try await api.request(.announcement(id: announcementId), token: token)
    }

    func uploadAnnouncementMedia(token: String, announcementId: String, images: [Data]) async throws -> AnnouncementDTO {
        let items = images.enumerated().map { idx, d in
            APIClient.UploadFileItem(
                data: d,
                filename: "image_\(idx).jpg",
                mimeType: "image/jpeg"
            )
        }
        // backend теперь возвращает AnnouncementOut
        return try await api.upload(.uploadAnnouncementMedia(id: announcementId), token: token, files: items)
    }

    func archiveAnnouncement(token: String, announcementId: String) async throws -> AnnouncementDTO {
        // PATCH без body
        struct EmptyBody: Encodable {}
        return try await api.request(.archiveAnnouncement(id: announcementId), body: EmptyBody(), token: token)
    }

    func deleteAnnouncement(token: String, announcementId: String) async throws -> Bool {
        struct EmptyBody: Encodable {}
        let resp: DeleteOKResponse = try await api.request(.deleteAnnouncement(id: announcementId), body: EmptyBody(), token: token)
        return resp.ok
    }

    func appealAnnouncement(token: String, announcementId: String, reason: String?) async throws -> AnnouncementDTO {
        let req = AppealRequest(reason: reason)
        return try await api.request(.appealAnnouncement(id: announcementId), body: req, token: token)
    }

    func createOffer(
        token: String,
        announcementId: String,
        message: String?,
        proposedPrice: Int?,
        pricingMode: OfferPricingMode,
        agreedPrice: Int?,
        minimumPriceAccepted: Bool
    ) async throws -> AnnouncementOffer {
        let request = CreateOfferRequestDTO(
            message: normalizedAnnouncementText(message),
            proposed_price: proposedPrice,
            pricing_mode: pricingMode.rawValue,
            agreed_price: agreedPrice,
            minimum_price_accepted: minimumPriceAccepted
        )
        let response: AnnouncementOfferDTO = try await api.request(
            .submitOffer(announcementID: announcementId),
            body: request,
            token: token
        )
        return response.domain
    }

    func fetchOffers(token: String, announcementId: String) async throws -> [AnnouncementOffer] {
        let response: [AnnouncementOfferDTO] = try await api.request(.announcementOffers(announcementID: announcementId), token: token)
        return response.map(\.domain)
    }

    func acceptOffer(token: String, announcementId: String, offerId: String) async throws -> AcceptedOfferResult {
        struct EmptyBody: Encodable {}
        let response: AcceptOfferResponseDTO = try await api.request(
            .acceptOffer(announcementID: announcementId, offerID: offerId),
            body: EmptyBody(),
            token: token
        )
        return response.domain
    }

    func rejectOffer(token: String, announcementId: String, offerId: String) async throws {
        struct EmptyBody: Encodable {}
        let _: OperationStatusResponseDTO = try await api.request(
            .rejectOffer(announcementID: announcementId, offerID: offerId),
            body: EmptyBody(),
            token: token
        )
    }

    func updateExecutionStage(token: String, announcementId: String, stage: String) async throws -> AnnouncementDTO {
        let request = ExecutionStageUpdateRequestDTO(stage: stage)
        return try await api.request(
            .updateExecutionStage(announcementID: announcementId),
            body: request,
            token: token
        )
    }
}

final class MockAnnouncementService: AnnouncementService {
    func createAnnouncement(token: String, request: CreateAnnouncementRequest) async throws -> AnnouncementDTO {
        let now = ISO8601DateFormatter().string(from: Date())
        return AnnouncementDTO(
            id: UUID().uuidString,
            user_id: "dev",
            category: request.category,
            title: request.title,
            status: "pending_review",
            data: request.data,
            created_at: now
        )
    }

    func myAnnouncements(token: String) async throws -> [AnnouncementDTO] {
        let now = ISO8601DateFormatter().string(from: Date())
        return [
            AnnouncementDTO(
                id: UUID().uuidString,
                user_id: "dev",
                category: "delivery",
                title: "Доставка по пути: забрать посылку",
                status: "needs_fix",
                data: [
                    "pickup_address": .string("Москва, Красная площадь"),
                    "point": .object(["lat": .double(55.75393), "lon": .double(37.620795)]),
                    "moderation": .object([
                        "decision": .object(["status": .string("needs_fix"), "message": .string("Нужно исправить: фото спорное")]),
                        "reasons": .array([
                            .object(["field": .string("media"), "code": .string("NSFW_REVIEW"), "details": .string("NSFW 0.45"), "can_appeal": .bool(true)])
                        ])
                    ])
                ],
                created_at: now
            )
        ]
    }

    func publicAnnouncements() async throws -> [AnnouncementDTO] {
        []
    }

    func fetchAnnouncement(token: String, announcementId: String) async throws -> AnnouncementDTO {
        if let announcement = try await myAnnouncements(token: token).first(where: { $0.id == announcementId }) {
            return announcement
        }
        if let announcement = try await publicAnnouncements().first(where: { $0.id == announcementId }) {
            return announcement
        }

        let now = ISO8601DateFormatter().string(from: Date())
        return AnnouncementDTO(
            id: announcementId,
            user_id: "dev",
            category: "delivery",
            title: "Объявление",
            status: "active",
            data: [:],
            created_at: now
        )
    }

    func uploadAnnouncementMedia(token: String, announcementId: String, images: [Data]) async throws -> AnnouncementDTO {
        // мок: сразу needs_fix
        var ann = try await myAnnouncements(token: token).first!
        ann = AnnouncementDTO(
            id: announcementId,
            user_id: ann.user_id,
            category: ann.category,
            title: ann.title,
            status: ann.status,
            data: ann.data,
            created_at: ann.created_at
        )
        return ann
    }

    func archiveAnnouncement(token: String, announcementId: String) async throws -> AnnouncementDTO {
        let now = ISO8601DateFormatter().string(from: Date())
        return AnnouncementDTO(id: announcementId, user_id: "dev", category: "delivery", title: "Archived", status: "archived", data: [:], created_at: now)
    }

    func deleteAnnouncement(token: String, announcementId: String) async throws -> Bool {
        true
    }

    func appealAnnouncement(token: String, announcementId: String, reason: String?) async throws -> AnnouncementDTO {
        let now = ISO8601DateFormatter().string(from: Date())
        return AnnouncementDTO(id: announcementId, user_id: "dev", category: "delivery", title: "Appeal", status: "pending_review", data: [:], created_at: now)
    }

    func createOffer(
        token: String,
        announcementId: String,
        message: String?,
        proposedPrice: Int?,
        pricingMode: OfferPricingMode,
        agreedPrice: Int?,
        minimumPriceAccepted: Bool
    ) async throws -> AnnouncementOffer {
        AnnouncementOffer(
            id: UUID().uuidString,
            announcementID: announcementId,
            performerID: "dev",
            message: normalizedAnnouncementText(message),
            proposedPrice: proposedPrice,
            agreedPrice: agreedPrice,
            pricingMode: pricingMode,
            minimumPriceAccepted: minimumPriceAccepted,
            canReoffer: true,
            status: "pending",
            createdAt: .now,
            performer: nil,
            performerStats: nil
        )
    }

    func fetchOffers(token: String, announcementId: String) async throws -> [AnnouncementOffer] {
        []
    }

    func acceptOffer(token: String, announcementId: String, offerId: String) async throws -> AcceptedOfferResult {
        AcceptedOfferResult(
            threadID: UUID().uuidString,
            offer: AnnouncementOffer(
                id: offerId,
                announcementID: announcementId,
                performerID: "dev",
                message: "Быстрый отклик",
                proposedPrice: nil,
                agreedPrice: 350,
                pricingMode: .quickMinPrice,
                minimumPriceAccepted: true,
                canReoffer: false,
                status: "accepted",
                createdAt: .now,
                performer: OfferPerformer(userID: "dev", displayName: "Исполнитель", city: "Москва", contact: nil, avatarURL: nil),
                performerStats: ProfileStats(ratingAverage: 4.9, ratingCount: 12, completedCount: 27, cancelledCount: 1)
            )
        )
    }

    func rejectOffer(token: String, announcementId: String, offerId: String) async throws { }

    func updateExecutionStage(token: String, announcementId: String, stage: String) async throws -> AnnouncementDTO {
        let now = ISO8601DateFormatter().string(from: Date())
        return AnnouncementDTO(
            id: announcementId,
            user_id: "dev",
            category: "delivery",
            title: "Обновлённый этап",
            status: stage == "completed" ? "completed" : "in_progress",
            data: [
                "task": .object([
                    "schema_version": .int(2),
                    "lifecycle": .object([
                        "status": .string(stage == "completed" ? "completed" : "in_progress"),
                        "deleted_at": .null,
                    ]),
                    "execution": .object([
                        "status": .string(stage),
                        "assignment_id": .string(UUID().uuidString),
                        "performer_user_id": .string("dev"),
                    ]),
                ]),
            ],
            created_at: now
        )
    }
}

private func normalizedAnnouncementText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
