import SwiftUI

struct RootView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var session: SessionStore   // <- ВОТ ЭТО ВАЖНО

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
    @EnvironmentObject var session: SessionStore   // <- чтобы logout обновлял UI

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MapScreen(vm: .init(service: container.taskService))
            }
            .tabItem { Label("Карта", systemImage: "map") }
            .tag(0)

            NavigationStack {
                RouteScreen(vm: .init(service: container.taskService))
            }
            .tabItem { Label("Маршрут", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
            .tag(1)

            NavigationStack {
                ChatsScreen(vm: .init(service: container.chatService))
            }
            .tabItem { Label("Чаты", systemImage: "bubble.left.and.bubble.right") }
            .tag(2)

            NavigationStack {
                ProfileScreen(vm: .init(service: container.profileService))
                    .toolbar {
                        Button("Logout") { session.logout() }
                    }
            }
            .tabItem { Label("Профиль", systemImage: "person.circle") }
            .tag(3)
        }
        .tint(Theme.ColorToken.turquoise)
    }
}
