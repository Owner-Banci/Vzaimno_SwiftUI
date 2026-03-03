import Foundation

protocol ChatService {
    func fetchThreads(token: String) async throws -> [ChatThreadPreview]
    func fetchMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage]
    func sendMessage(token: String, threadID: String, text: String) async throws -> ChatMessage
}

final class NetworkChatService: ChatService {
    private let api: APIClient
    private let encoder = ISO8601DateFormatter()

    init(api: APIClient = APIClient()) {
        self.api = api
        self.encoder.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func fetchThreads(token: String) async throws -> [ChatThreadPreview] {
        let response: [ChatThreadPreviewDTO] = try await api.request(.chats, token: token)
        return response.map(\.domain)
    }

    func fetchMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        let beforeValue = before.map { encoder.string(from: $0) }
        let response: [ChatMessageDTO] = try await api.request(
            .chatMessages(threadID: threadID, limit: limit, before: beforeValue),
            token: token
        )
        return response.map(\.domain)
    }

    func sendMessage(token: String, threadID: String, text: String) async throws -> ChatMessage {
        let request = SendChatMessageRequestDTO(text: text)
        let response: ChatMessageDTO = try await api.request(.sendChatMessage(threadID: threadID), body: request, token: token)
        return response.domain
    }
}
