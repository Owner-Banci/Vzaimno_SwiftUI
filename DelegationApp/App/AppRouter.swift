import SwiftUI

/// Опциональный "роутер", чтобы можно было использовать как корневой View в превью/в будущем.
struct AppRouter: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        RootView()
            .environmentObject(container)
            .environmentObject(container.session)
    }
}

/// Корневой экран приложения: проверка сессии → авторизация → основной таббар.
struct RootView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var session: SessionStore

    var body: some View {
        Group {
            if !AppConfig.authEnabled {
                MainTabView()
            } else {
                if session.isRestoring {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Проверяем сессию…")
                            .font(.system(size: 14))
                    }
                } else {
                    if session.isAuthorized {
                        MainTabView()
                    } else {
                        AuthScreen()
                    }
                }
            }
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var session: SessionStore

    @State private var tab: AppTab = .map

    var body: some View {
        ZStack {
            contentView
        }
        // Кастомный TabBar снизу так, чтобы контент не уезжал под него
        .safeAreaInset(edge: .bottom) {
            LiquidTabBar(selection: $tab)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .tint(Theme.ColorToken.turquoise)
    }

    @ViewBuilder
    private var contentView: some View {
        switch tab {
        case .map:
            NavigationStack {
                MapScreen(
                    vm: .init(
                        service: container.taskService,
                        searchService: AddressSearchService()
                    ),
                    mapMode: MapDisplayConfig.defaultMode()
                )
            }

        case .route:
            NavigationStack {
                RouteScreen(vm: .init(service: container.taskService))
            }

        case .ads:
            NavigationStack {
                MyAdsScreen(
                    vm: .init(
                        service: container.announcementService,
                        session: session
                    )
                )
            }

        case .chats:
            NavigationStack {
                ChatsScreen(vm: .init(service: container.chatService))
            }

        case .profile:
            NavigationStack {
                ProfileScreen(vm: .init(service: container.profileService))
                    .toolbar {
                        if AppConfig.authEnabled {
                            Button("Logout") { session.logout() }
                        }
                    }
            }
        }
    }
}
