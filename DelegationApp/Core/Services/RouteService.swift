import Foundation
import MapKit

protocol RouteService {
    func fetchRouteContext(announcementID: String, token: String) async throws -> RouteContextDTO
    func fetchMyCurrentRouteContext(token: String) async throws -> RouteContextDTO
    func buildRoute(request: RouteBuildRequest, token: String) async throws -> RouteDetailsDTO
}

final class NetworkRouteService: RouteService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func fetchRouteContext(announcementID: String, token: String) async throws -> RouteContextDTO {
        try await api.request(.announcementRouteContext(announcementID: announcementID), token: token)
    }

    func fetchMyCurrentRouteContext(token: String) async throws -> RouteContextDTO {
        try await api.request(.myCurrentRouteContext, token: token)
    }

    func buildRoute(request: RouteBuildRequest, token: String) async throws -> RouteDetailsDTO {
        try await api.request(.routeBuild, body: request, token: token)
    }
}

final class MockRouteService: RouteService {
    func fetchRouteContext(announcementID: String, token: String) async throws -> RouteContextDTO {
        try await fetchMyCurrentRouteContext(token: token)
    }

    func fetchMyCurrentRouteContext(token: String) async throws -> RouteContextDTO {
        RouteContextDTO(
            entityID: UUID().uuidString,
            startAddress: "Пушкинская площадь",
            endAddress: "Станция МЦК Площадь Гагарина",
            start: RouteCoordinateDTO(lat: 55.751244, lon: 37.618423),
            end: RouteCoordinateDTO(lat: 55.729390, lon: 37.603020),
            radiusM: 500,
            travelMode: .driving
        )
    }

    func buildRoute(request: RouteBuildRequest, token: String) async throws -> RouteDetailsDTO {
        RouteDetailsDTO(
            entityID: request.announcementID ?? UUID().uuidString,
            startAddress: request.startAddress ?? "Пушкинская площадь",
            endAddress: request.endAddress ?? "Станция МЦК Площадь Гагарина",
            distanceMeters: request.distanceMeters ?? 12_500,
            durationSeconds: request.durationSeconds ?? 45 * 60,
            distanceText: "12.5 км",
            durationText: "45 мин",
            polyline: request.polyline.isEmpty
                ? [
                    [55.751244, 37.618423],
                    [55.746011, 37.611900],
                    [55.729390, 37.603020],
                ]
                : request.polyline,
            tasksByRoute: [
                TaskByRouteDTO(
                    id: UUID().uuidString,
                    title: "Подхватить письмо",
                    category: "delivery",
                    addressText: "ул. Льва Толстого, 16",
                    latitude: 55.7334,
                    longitude: 37.5888,
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
                    latitude: 55.7183,
                    longitude: 37.6074,
                    distanceToRouteMeters: 320,
                    priceText: "150 ₽",
                    previewImageURL: nil,
                    status: "active"
                ),
            ]
        )
    }
}

struct RouteGeometry {
    let polyline: [[Double]]
    let distanceMeters: Int
    let durationSeconds: Int
}

protocol RouteGeometryBuilding {
    func buildRoute(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        travelMode: RouteTravelMode
    ) async throws -> RouteGeometry
}

final class AppleDirectionsRouteBuilder: RouteGeometryBuilding {
    func buildRoute(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        travelMode: RouteTravelMode
    ) async throws -> RouteGeometry {
        let request = MKDirections.Request()
        request.source = mapItem(for: start)
        request.destination = mapItem(for: end)
        request.transportType = travelMode.appleTransportType
        request.requestsAlternateRoutes = false

        let response = try await calculate(request: request)
        guard let route = response.routes.first else {
            throw RouteGeometryBuildError.emptyRoute
        }

        let coordinates = route.polyline.coordinatePairs
        guard coordinates.count >= 2 else {
            throw RouteGeometryBuildError.emptyGeometry
        }

        return RouteGeometry(
            polyline: coordinates,
            distanceMeters: Int(route.distance.rounded()),
            durationSeconds: max(1, Int(route.expectedTravelTime.rounded()))
        )
    }

    private func calculate(request: MKDirections.Request) async throws -> MKDirections.Response {
        let directions = MKDirections(request: request)

        return try await withCheckedThrowingContinuation { continuation in
            directions.calculate { response, error in
                if let response {
                    continuation.resume(returning: response)
                } else if let error {
                    continuation.resume(throwing: RouteGeometryBuildError.appleDirections(error.localizedDescription))
                } else {
                    continuation.resume(throwing: RouteGeometryBuildError.unknown)
                }
            }
        }
    }

    private func mapItem(for coordinate: CLLocationCoordinate2D) -> MKMapItem {
        MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    }
}

enum RouteGeometryBuildError: LocalizedError {
    case emptyRoute
    case emptyGeometry
    case appleDirections(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .emptyRoute:
            return "Apple Maps не вернул ни одного маршрута."
        case .emptyGeometry:
            return "Apple Maps не вернул геометрию маршрута."
        case let .appleDirections(message):
            return "Не удалось построить маршрут через Apple Maps: \(message)"
        case .unknown:
            return "Не удалось построить маршрут через Apple Maps."
        }
    }
}

private extension RouteTravelMode {
    var appleTransportType: MKDirectionsTransportType {
        switch self {
        case .driving:
            return .automobile
        case .walking:
            return .walking
        }
    }
}

private extension MKPolyline {
    var coordinatePairs: [[Double]] {
        var coordinates = Array(repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates.map { [$0.latitude, $0.longitude] }
    }
}
