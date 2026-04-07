import Foundation

final class MockChatService: ChatService {
    func fetchThreads(token: String) async throws -> [ChatThreadPreview] {
        [
            ChatThreadPreview(
                threadID: UUID().uuidString,
                kind: "support",
                partnerID: "support-1",
                partnerName: "Поддержка Vzaimno",
                partnerAvatarURL: nil,
                lastMessageText: "Здравствуйте! Чем можем помочь?",
                lastMessageAt: .now,
                unreadCount: 1,
                announcementID: nil,
                announcementTitle: nil,
                isPinned: true
            ),
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
                announcementTitle: "Доставка посылки",
                isPinned: false
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
                announcementTitle: "Помочь донести сумки",
                isPinned: false
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

    func ensureSupportThread(token: String) async throws -> String {
        "mock-support-thread"
    }

    func fetchSupportMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        [
            ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "support-1", text: "Здравствуйте! Чем можем помочь?", createdAt: Date().addingTimeInterval(-180)),
            ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "dev", text: "Нужна помощь с заказом", createdAt: Date().addingTimeInterval(-60)),
        ]
    }

    func sendSupportMessage(token: String, threadID: String, text: String) async throws -> ChatMessage {
        ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "dev", text: text, createdAt: .now)
    }

    func fetchReportReasonOptions(token: String) async throws -> [ReportReasonOption] {
        [
            ReportReasonOption(
                code: "abuse_insults",
                title: "Оскорбления и абьюз",
                description: "Грубость, унижения, токсичное общение.",
                allowedTargetTypes: ["message", "user"]
            ),
            ReportReasonOption(
                code: "spam",
                title: "Спам",
                description: "Навязчивые или повторяющиеся сообщения.",
                allowedTargetTypes: ["message", "user", "task", "announcement"]
            ),
            ReportReasonOption(
                code: "other",
                title: "Другое",
                description: "Опишите проблему своими словами.",
                allowedTargetTypes: ["message", "user", "task", "announcement"]
            ),
        ]
    }

    func submitReport(
        token: String,
        targetType: String,
        targetID: String,
        reasonCode: String,
        reasonText: String?
    ) async throws {
    }
}
