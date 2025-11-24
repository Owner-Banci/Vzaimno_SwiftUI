//
// AppContainer.swift
// iCuno test
//
// Created by maftuna murtazaeva on 07.11.2025.
//

import Foundation
import SwiftUI

/// Простой DI-контейнер: подставляем моки сервисов.
final class AppContainer: ObservableObject {
    let taskService: TaskService
    let chatService: ChatService
    let profileService: ProfileService

    init(
        taskService: TaskService,
        chatService: ChatService,
        profileService: ProfileService,
    ) {
        self.taskService = taskService
        self.chatService = chatService
        self.profileService = profileService
    }
}

extension AppContainer {
    /// Контейнер для превью/раннего старта — только заглушки.
    static let preview = AppContainer(
        taskService: MockTaskService(),
        chatService: MockChatService(),
        profileService: MockProfileService()
    )
}
