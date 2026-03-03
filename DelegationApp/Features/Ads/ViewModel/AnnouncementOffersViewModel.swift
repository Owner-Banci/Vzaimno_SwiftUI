import Foundation

@MainActor
final class AnnouncementOffersViewModel: ObservableObject {
    @Published private(set) var offers: [AnnouncementOffer] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var processingOfferID: String?
    @Published var errorText: String?

    private let announcementID: String
    private let service: AnnouncementService
    private let session: SessionStore
    private var hasLoadedOnce: Bool = false

    init(announcementID: String, service: AnnouncementService, session: SessionStore) {
        self.announcementID = announcementID
        self.service = service
        self.session = session
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        await reload()
    }

    func reload(showLoader: Bool = true) async {
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            offers = []
            return
        }

        if showLoader {
            isLoading = true
        }
        defer {
            if showLoader {
                isLoading = false
            }
        }

        do {
            offers = try await service.fetchOffers(token: token, announcementId: announcementID)
            errorText = nil
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            errorText = error.localizedDescription
        }
    }

    func acceptOffer(_ offerID: String) async -> AcceptedOfferResult? {
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            return nil
        }

        processingOfferID = offerID
        defer { processingOfferID = nil }

        do {
            let result = try await service.acceptOffer(token: token, announcementId: announcementID, offerId: offerID)
            if let index = offers.firstIndex(where: { $0.id == offerID }) {
                offers[index] = result.offer
            } else {
                offers.insert(result.offer, at: 0)
            }
            errorText = nil
            return result
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return nil
            }
            errorText = error.localizedDescription
            return nil
        }
    }

    func rejectOffer(_ offerID: String) async -> Bool {
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            return false
        }

        processingOfferID = offerID
        defer { processingOfferID = nil }

        do {
            try await service.rejectOffer(token: token, announcementId: announcementID, offerId: offerID)
            offers.removeAll { $0.id == offerID }
            errorText = nil
            return true
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return false
            }
            errorText = error.localizedDescription
            return false
        }
    }
}
