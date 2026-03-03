#if canImport(YandexMapsMobile)
import YandexMapsMobile
#endif

/// Централизованная настройка Yandex MapKit.
enum YandexMapConfigurator {
    private static var isConfigured = false

    static func configureIfNeeded() {
        // В SwiftUI Preview вообще не инициализируем SDK.
//        if RuntimeEnvironment.isPreview { return }
        guard !isConfigured else { return }

        #if canImport(YandexMapsMobile)
        // ⬇ сюда твой реальный ключ
        YMKMapKit.setApiKey("df3f9145-2080-42b7-9b91-b879c34236bb")
        YMKMapKit.sharedInstance()
        #endif
        isConfigured = true
    }
}
