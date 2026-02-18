//
//  MyAdsViewModel.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import Foundation

@MainActor
final class MyAdsViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorText: String?
    @Published private(set) var items: [AnnouncementDTO] = []

    let service: AnnouncementService
    let session: SessionStore

    init(service: AnnouncementService, session: SessionStore) {
        self.service = service
        self.session = session
    }

    func reload() async {
        guard let token = session.token else {
            errorText = "Нет токена сессии"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            items = try await service.myAnnouncements(token: token)
        } catch {
            errorText = error.localizedDescription
        }
    }

    // MARK: - Derived counts
    var activeCount: Int { items.filter { $0.status == "active" }.count }
    var draftCount: Int { items.filter { $0.status == "draft" }.count }
    var archivedCount: Int { items.filter { $0.status == "archived" }.count }

    func filteredItems(for filter: AdsFilter) -> [AnnouncementDTO] {
        switch filter {
        case .active:
            return items.filter { $0.status == "active" }
        case .drafts:
            return items.filter { $0.status == "draft" }
        case .archived:
            return items.filter { $0.status == "archived" }
        }
    }
}

enum AdsFilter: String, CaseIterable, Identifiable {
    case active = "Активные"
    case drafts = "Черновики"
    case archived = "Архив"

    var id: String { rawValue }
}
