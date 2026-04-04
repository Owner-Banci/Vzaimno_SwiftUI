import SwiftUI

struct AppRouter: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        RootView()
            .environmentObject(container)
            .environmentObject(container.session)
    }
}

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
    @StateObject private var tabBarVisibility = LiquidTabBarVisibilityStore()

    var body: some View {
        ZStack { contentView }
            .environment(\.liquidTabBarVisibilityStore, tabBarVisibility)
            .overlay(alignment: .top) {
                if let bannerText = session.connectivityBannerText {
                    ConnectivityBanner(text: bannerText)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !tabBarVisibility.isHidden {
                    LiquidTabBar(selection: $tab)
                        .padding(.horizontal, AppChrome.LiquidTabBar.horizontalPadding)
                        .padding(.bottom, AppChrome.LiquidTabBar.bottomPadding)
                }
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
                        announcementService: container.announcementService,
                        searchService: AddressSearchService()
                    ),
                    mapMode: MapDisplayConfig.defaultMode()
                )
            }

        case .route:
            NavigationStack {
                RouteScreen(
                    vm: .init(
                        routeService: container.routeService,
                        announcementService: container.announcementService,
                        session: session
                    )
                )
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
                ChatsScreen(service: container.chatService, profileService: container.profileService, session: session)
            }

        case .profile:
            NavigationStack {
                ProfileScreen(service: container.profileService, session: session)
            }
        }
    }
}

private struct ConnectivityBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.82))
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
    }
}
