import Foundation

final class MockChatService: ChatService {
    func loadChats() -> [ChatPreview] {
        [
            .init(initials: "С", name: "Бобо джекс", lastMessage: "Ман сасилдок", time: "14:30", unreadCount: 1),
            .init(initials: "П", name: "Равонак", lastMessage: "Равонак на связи", time: "Вчера", unreadCount: 0)
        ]
    }
}
