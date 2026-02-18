import Foundation

final class MockChatService: ChatService {
    func loadChats() -> [ChatPreview] {
        [
            .init(initials: "С", name: "Саша", lastMessage: "Ман сасилдок", time: "14:30", unreadCount: 1),
            .init(initials: "П", name: "Павел", lastMessage: "Посылку доставил", time: "Вчера", unreadCount: 0)
        ]
    }
}
