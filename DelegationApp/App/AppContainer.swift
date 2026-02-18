import Foundation
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let taskService: TaskService
    let chatService: ChatService
    let profileService: ProfileService
    let announcementService: AnnouncementService
    let authService: AuthService

    // ВАЖНО: lazy — чтобы инициализация SessionStore произошла уже на MainActor
    lazy var session: SessionStore = SessionStore(auth: authService)

    init(
        taskService: TaskService,
        chatService: ChatService,
        profileService: ProfileService,
        announcementService: AnnouncementService,
        authService: AuthService
    ) {
        self.taskService = taskService
        self.chatService = chatService
        self.profileService = profileService
        self.announcementService = announcementService
        self.authService = authService
    }
}

extension AppContainer {
    @MainActor
    static let preview = AppContainer(
        taskService: MockTaskService(),
        chatService: MockChatService(),
        profileService: MockProfileService(),
        announcementService: MockAnnouncementService(),
        authService: NetworkAuthService()
    )
}
