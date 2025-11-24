import Foundation

final class ChatsViewModel: ObservableObject {
    @Published var chats: [ChatPreview] = []
    
    private let service: ChatService
    init(service: ChatService) {
        self.service = service
        self.chats = service.loadChats()
    }
}
