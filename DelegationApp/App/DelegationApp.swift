import SwiftUI
import YandexMapsMobile
//
//@main
//struct DelegationApp: App {
//    @StateObject private var container = AppContainer.preview
//    
//    init() {
//        // ✅ Инициализация Yandex MapKit
//        // сюда поставь свой ключ, тот же, что ты уже использовала в тестовом проекте
//        YMKMapKit.setApiKey("df3f9145-2080-42b7-9b91-b879c34236bb")
//        YMKMapKit.sharedInstance()
//    }
//    
////    var body: some Scene {
////        WindowGroup {
////            RootView()
////                .environmentObject(container)
////        }
////    }
//    let service = MockTaskService()
//    let searchService = AddressSearchService()
//    let vm = MapViewModel(service: service, searchService: searchService)
//    
//    var body: some Scene {
//        WindowGroup {
//            MapScreen(vm: vm)
//        }
//    }
//}
//
////#Preview {
////    let service = MockTaskService()
////    let searchService = AddressSearchService()
////    let vm = MapViewModel(service: service, searchService: searchService)
////    MapScreen(vm: vm)
////}

//@main
//struct DelegationApp: App {
//    @StateObject private var container = AppContainer.preview
//    @StateObject private var mapVM: MapViewModel
//
//    init() {
//        // Инициализация Yandex MapKit
//        YMKMapKit.setApiKey("df3f9145-2080-42b7-9b91-b879c34236bb")
//        YMKMapKit.sharedInstance()
//
//        let service = MockTaskService()
//        let searchService = AddressSearchService()
//        _mapVM = StateObject(wrappedValue: MapViewModel(service: service,
//                                                        searchService: searchService))
//    }
//
//    var body: some Scene {
//        WindowGroup {
////            MapScreen(vm: mapVM)
////            ChatsScreen(
////                vm: ChatsViewModel(service: MockChatService())
////            )
//            
//            
////            NavigationStack {
////                RouteScreen(vm: PreviewData.routeVM)
////            }
////            .preferredColorScheme(.light)
//            
//            let service = MockTaskService()
//            let searchService = AddressSearchService()
//            let vm = MapViewModel(service: service, searchService: searchService)
//
//            return NavigationStack {
//                MapScreen(vm: vm)
//            }
//        }
//    }
//}

@main
struct DelegationApp: App {
    /// Общий контейнер зависимостей.
    @StateObject private var container = AppContainer.preview

    init() {
        // При желании можно принудительно заранее инициализировать SDK карт:
        // YandexMapConfigurator.configureIfNeeded()
        //
        // Но сейчас это делает сам код карты и сервисы (AddressSearchService / YandexMapView),
        // так что точка входа не зависит от конкретного Map SDK.
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .ignoresSafeArea()
        }
    }
}

/// Утилита, чтобы понимать, что код выполняется в SwiftUI Preview.
enum RuntimeEnvironment {
    static var isPreview: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        }
        #endif
        return false
    }
}
