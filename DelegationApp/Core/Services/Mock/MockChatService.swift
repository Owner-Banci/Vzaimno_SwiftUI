import Foundation

final class MockChatService: ChatService {
    func fetchThreads(token: String) async throws -> [ChatThreadPreview] {
        [
            ChatThreadPreview(
                threadID: UUID().uuidString,
                kind: "offer",
                partnerID: "mock-1",
                partnerName: "Саша",
                partnerAvatarURL: nil,
                lastMessageText: "Ман сасилдок",
                lastMessageAt: .now,
                unreadCount: 1,
                announcementID: "mock-task-1",
                announcementTitle: "Доставка посылки"
            ),
            ChatThreadPreview(
                threadID: UUID().uuidString,
                kind: "offer",
                partnerID: "mock-2",
                partnerName: "Павел",
                partnerAvatarURL: nil,
                lastMessageText: "Посылку доставил",
                lastMessageAt: Date().addingTimeInterval(-86_400),
                unreadCount: 0,
                announcementID: "mock-task-2",
                announcementTitle: "Помочь донести сумки"
            ),
        ]
    }

    func fetchMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        [
            ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "mock-1", text: "Здравствуйте", createdAt: Date().addingTimeInterval(-300)),
            ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "dev", text: "Добрый день", createdAt: Date().addingTimeInterval(-120)),
        ]
    }

    func sendMessage(token: String, threadID: String, text: String) async throws -> ChatMessage {
        ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "dev", text: text, createdAt: .now)
    }
}
