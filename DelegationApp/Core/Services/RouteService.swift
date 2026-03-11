import Foundation

protocol RouteService {
    func fetchRoute(announcementID: String, token: String) async throws -> RouteDetailsDTO
    func fetchMyCurrentRoute(token: String) async throws -> RouteDetailsDTO
}

final class NetworkRouteService: RouteService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func fetchRoute(announcementID: String, token: String) async throws -> RouteDetailsDTO {
        try await api.request(.announcementRoute(announcementID: announcementID), token: token)
    }

    func fetchMyCurrentRoute(token: String) async throws -> RouteDetailsDTO {
        try await api.request(.myCurrentRoute, token: token)
    }
}

final class MockRouteService: RouteService {
    func fetchRoute(announcementID: String, token: String) async throws -> RouteDetailsDTO {
        try await fetchMyCurrentRoute(token: token)
    }

    func fetchMyCurrentRoute(token: String) async throws -> RouteDetailsDTO {
        RouteDetailsDTO(
            entityID: UUID().uuidString,
            startAddress: "Пушкинская площадь",
            endAddress: "Станция МЦК Площадь Гагарина",
            distanceMeters: 12_500,
            durationSeconds: 45 * 60,
            distanceText: "12.5 км",
            durationText: "45 мин",
            polyline: [
                [55.751244, 37.618423],
                [55.746011, 37.611900],
                [55.729390, 37.603020],
            ],
            tasksByRoute: [
                TaskByRouteDTO(
                    id: UUID().uuidString,
                    title: "Подхватить письмо",
                    category: "delivery",
                    addressText: "ул. Льва Толстого, 16",
                    distanceToRouteMeters: 182,
                    priceText: "350 ₽",
                    previewImageURL: nil,
                    status: "active"
                ),
                TaskByRouteDTO(
                    id: UUID().uuidString,
                    title: "Купить кофе",
                    category: "help",
                    addressText: "ул. Шаболовка, 30",
                    distanceToRouteMeters: 320,
                    priceText: "150 ₽",
                    previewImageURL: nil,
                    status: "active"
                ),
            ]
        )
    }
}
