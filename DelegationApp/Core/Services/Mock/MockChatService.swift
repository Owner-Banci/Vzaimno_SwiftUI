import Foundation

final class MockChatService: ChatService {
    func loadChats() -> [ChatPreview] {
        [
            .init(initials: "С", name: "Сергей Л.", lastMessage: "Спасибо, жду!", time: "14:30", unreadCount: 2),
            .init(initials: "П", name: "Пётр К.", lastMessage: "Могу взять это задание", time: "Вчера", unreadCount: 0)
        ]
    }
}
