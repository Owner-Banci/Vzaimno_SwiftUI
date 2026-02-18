//
//  MockAnnouncementService.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import Foundation

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
                data: ["budget": .int(300)],
                created_at: now
            ),
            AnnouncementDTO(
                id: UUID().uuidString,
                user_id: "dev",
                category: "help",
                title: "Помощь с мелким поручением",
                status: "draft",
                data: [:],
                created_at: now
            )
        ]
    }
}
