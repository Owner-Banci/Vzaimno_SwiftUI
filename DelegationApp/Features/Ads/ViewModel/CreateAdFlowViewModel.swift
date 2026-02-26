//
//  CreateAdFlowViewModel.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import Foundation

@MainActor
final class CreateAdFlowViewModel: ObservableObject {
    @Published var isSubmitting: Bool = false
    @Published var errorText: String?

    private let service: AnnouncementService
    private let session: SessionStore
    private let searchService: AddressSearchService

    init(
        service: AnnouncementService,
        session: SessionStore,
        searchService: AddressSearchService = AddressSearchService()
    ) {
        self.service = service
        self.session = session
        self.searchService = searchService
    }

    func submit(draft: CreateAdDraft) async -> AnnouncementDTO? {
        errorText = nil

        guard let token = session.token else {
            errorText = "Нет токена сессии"
            return nil
        }

        if let validationError = await draft.validateForSubmit(searchService: searchService) {
            errorText = validationError
            return nil
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let req = draft.toCreateRequest()
            let created = try await service.createAnnouncement(token: token, request: req)
            return created
        } catch {
            errorText = error.localizedDescription
            return nil
        }
    }
}
