import SwiftUI
#if canImport(YandexMapsMobile)
import YandexMapsMobile
#endif

@main
struct DelegationApp: App {
    @StateObject private var container = AppContainer.live


    init() {
        #if canImport(YandexMapsMobile)
        YMKMapKit.setApiKey("df3f9145-2080-42b7-9b91-b879c34236bb")
        YMKMapKit.sharedInstance()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.session)  // <- ВОТ ЭТО ВАЖНО
        }
    }
}
