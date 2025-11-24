//
//  RouteView.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 08.11.2025.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var container: AppContainer
    @State private var selectedTab = 0
    @State private var showCreate = false

    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                MapScreen(vm: .init(service: container.taskService))
                    .tabItem { Label("Карта", systemImage: "map") }
                    .tag(0)
                
                RouteScreen(vm: .init(service: container.taskService))
                    .tabItem { Label("Маршрут", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
                    .tag(1)
                
//                FloatingPlusButton {
//                    showCreate.toggle()
//                }
//                .padding(.bottom, 16)
//                .sheet(isPresented: $showCreate) {
//                    Text("Заглушка создания задания")
//                        .font(.title3.bold())
//                        .padding()
//                }

                MapScreen(vm: .init(service: container.taskService))
                
                ChatsScreen(vm: .init(service: container.chatService))
                    .tabItem { Label("Чаты", systemImage: "bubble.left.and.bubble.right") }
                    .tag(2)
                
                ProfileScreen(vm: .init(service: container.profileService))
                    .tabItem { Label("Профиль", systemImage: "person.circle") }
                    .tag(3)
            }
            .tint(Theme.ColorToken.turquoise)
            
        }
        .background(Color.black)
    }
}
