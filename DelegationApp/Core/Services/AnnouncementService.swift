import Foundation

struct DeleteOKResponse: Decodable {
    let ok: Bool
}

protocol AnnouncementService {
    func createAnnouncement(token: String, request: CreateAnnouncementRequest) async throws -> AnnouncementDTO
    func myAnnouncements(token: String) async throws -> [AnnouncementDTO]
    func publicAnnouncements() async throws -> [AnnouncementDTO]

    func uploadAnnouncementMedia(token: String, announcementId: String, images: [Data]) async throws -> AnnouncementDTO

    func archiveAnnouncement(token: String, announcementId: String) async throws -> AnnouncementDTO
    func deleteAnnouncement(token: String, announcementId: String) async throws -> Bool

    // оставляем на будущее
    func appealAnnouncement(token: String, announcementId: String, reason: String?) async throws -> AnnouncementDTO
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
}
