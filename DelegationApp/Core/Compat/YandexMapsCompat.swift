import Foundation

#if !canImport(YandexMapsMobile)
struct YMKPoint: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct YMKPolyline: Equatable, Sendable {
    init() {}
}
#endif
