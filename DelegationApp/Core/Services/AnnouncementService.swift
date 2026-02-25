//
//  AnnouncementService.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import Foundation

protocol AnnouncementService {
    func createAnnouncement(token: String, request: CreateAnnouncementRequest) async throws -> AnnouncementDTO
    func myAnnouncements(token: String) async throws -> [AnnouncementDTO]

    // Для карты: публичные активные объявления (без токена)
    func publicAnnouncements() async throws -> [AnnouncementDTO]
}

final class NetworkAnnouncementService: AnnouncementService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func createAnnouncement(token: String, request: CreateAnnouncementRequest) async throws -> AnnouncementDTO {
        try await api.request(.createAnnouncement, body: request, token: token)
    }

    func myAnnouncements(token: String) async throws -> [AnnouncementDTO] {
        try await api.request(.myAnnouncements, token: token)
    }

    func publicAnnouncements() async throws -> [AnnouncementDTO] {
        try await api.request(.publicAnnouncements)
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
            status: request.status,
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
                status: "active",
                data: [
                    "pickup_address": .string("Москва, Красная площадь"),
                    "point": .object(["lat": .double(55.75393), "lon": .double(37.620795)])
                ],
                created_at: now
            )
        ]
    }

    func publicAnnouncements() async throws -> [AnnouncementDTO] {
        // Для превью/моков можно вернуть то же самое
        try await myAnnouncements(token: "DEV_TOKEN")
    }
}
