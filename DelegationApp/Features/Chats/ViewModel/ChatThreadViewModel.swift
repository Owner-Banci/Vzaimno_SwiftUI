import Foundation

@MainActor
final class ChatThreadViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var draftText: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSending: Bool = false
    @Published var errorText: String?

    let thread: ChatThreadPreview

    private let service: ChatService
    private let session: SessionStore

    init(thread: ChatThreadPreview, service: ChatService, session: SessionStore) {
        self.thread = thread
        self.service = service
        self.session = session
    }

    var currentUserID: String? {
        session.me?.id
    }

    var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func loadMessages(showLoader: Bool = true) async {
        guard let token = session.token else {
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
            messages = try await service.fetchMessages(token: token, threadID: thread.threadID, limit: 50, before: nil)
            errorText = nil
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            errorText = error.localizedDescription
        }
    }

    func sendMessage() async {
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            return
        }

        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            let message = try await service.sendMessage(token: token, threadID: thread.threadID, text: text)
            messages.append(message)
            draftText = ""
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
