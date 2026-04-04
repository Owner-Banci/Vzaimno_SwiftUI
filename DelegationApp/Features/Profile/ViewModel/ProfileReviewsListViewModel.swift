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
    @Published private(set) var summary: ReviewSummary = .empty
    @Published var selectedRole: ReviewRole

    private let service: ProfileService
    private let session: SessionStore

    init(service: ProfileService, session: SessionStore, initialRole: ReviewRole = .performer) {
        self.service = service
        self.session = session
        self.selectedRole = initialRole
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func reload() async {
        await load()
    }

    func selectRole(_ role: ReviewRole) async {
        selectedRole = role
        await load()
    }

    private func load() async {
        guard let token = session.token else {
            state = .error("Сессия истекла. Войдите снова.")
            return
        }

        state = .loading

        do {
            let feed = try await service.fetchMyReviewsFeed(token: token, limit: 50, offset: 0, role: selectedRole)
            self.reviews = feed.reviews
            self.summary = feed.summary
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
