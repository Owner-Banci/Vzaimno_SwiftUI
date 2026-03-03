import Foundation

@MainActor
final class ProfileReviewsListViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var state: ViewState = .idle
    @Published private(set) var reviews: [UserProfileReview] = []

    private let service: ProfileService
    private let session: SessionStore

    init(service: ProfileService, session: SessionStore) {
        self.service = service
        self.session = session
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func reload() async {
        await load()
    }

    private func load() async {
        guard let token = session.token else {
            state = .error("Сессия истекла. Войдите снова.")
            return
        }

        state = .loading

        do {
            let reviews = try await service.fetchMyReviews(token: token, limit: 50, offset: 0)
            self.reviews = reviews
            self.state = .loaded
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }

            self.state = .error(error.localizedDescription)
        }
    }
}
