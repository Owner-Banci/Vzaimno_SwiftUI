import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published private(set) var state: ViewState = .idle
    @Published private(set) var profile: UserProfile?
    @Published private(set) var reviews: [UserProfileReview] = []
    @Published var darkMode: Bool = false

    private let service: ProfileService
    private let session: SessionStore

    init(service: ProfileService, session: SessionStore) {
        self.service = service
        self.session = session
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load(showLoadingState: true)
    }

    func reload() async {
        await load(showLoadingState: profile == nil)
    }

    func didUpdateProfile(_ updatedProfile: UserProfile) {
        profile = updatedProfile
        state = .loaded
    }

    private func load(showLoadingState: Bool) async {
        guard let token = session.token else {
            state = .error("Сессия истекла. Войдите снова.")
            return
        }

        if showLoadingState {
            state = .loading
        }

        do {
            async let meProfile = service.fetchMeProfile(token: token)
            async let myReviews = service.fetchMyReviews(token: token, limit: 2, offset: 0)
            let (profile, reviews) = try await (meProfile, myReviews)

            self.profile = profile
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
