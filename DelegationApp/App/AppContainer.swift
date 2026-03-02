import Foundation
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let taskService: TaskService
    let chatService: ChatService
    let profileService: ProfileService
    let deviceService: DeviceService
    let announcementService: AnnouncementService
    let authService: AuthService

    // ВАЖНО: lazy — чтобы инициализация SessionStore произошла уже на MainActor
    lazy var session: SessionStore = SessionStore(
        auth: authService,
        deviceService: deviceService
    )

    init(
        taskService: TaskService,
        chatService: ChatService,
        profileService: ProfileService,
        deviceService: DeviceService,
        announcementService: AnnouncementService,
        authService: AuthService
    ) {
        self.taskService = taskService
        self.chatService = chatService
        self.profileService = profileService
        self.deviceService = deviceService
        self.announcementService = announcementService
        self.authService = authService
    }
}

extension AppContainer {
    @MainActor
    static let live = AppContainer(
        taskService: MockTaskService(),          // пока можно оставить мок
        chatService: MockChatService(),          // пока мок
        profileService: NetworkProfileService(),
        deviceService: NetworkDeviceService(),
        announcementService: NetworkAnnouncementService(), // ВАЖНО: сеть
        authService: NetworkAuthService()
    )
}
