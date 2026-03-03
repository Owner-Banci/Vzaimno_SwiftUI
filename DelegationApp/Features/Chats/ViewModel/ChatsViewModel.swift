import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var chats: [ChatThreadPreview] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorText: String?

    private let service: ChatService
    private let session: SessionStore

    init(service: ChatService, session: SessionStore) {
        self.service = service
        self.session = session
    }

    func reload(showLoader: Bool = true) async {
        guard let token = session.token else {
            chats = []
            errorText = "Сессия не найдена. Войдите снова."
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
            chats = try await service.fetchThreads(token: token)
            errorText = nil
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            errorText = error.localizedDescription
        }
    }
}
