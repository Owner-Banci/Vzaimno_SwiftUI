import CoreLocation
import Foundation

enum RouteTravelMode: String, Codable {
    case driving
    case walking

    var apiValue: String { rawValue }
}

struct RouteCoordinateDTO: Codable, Hashable {
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct RouteContextDTO: Decodable {
    let entityID: String
    let startAddress: String
    let endAddress: String
    let start: RouteCoordinateDTO
    let end: RouteCoordinateDTO
    let radiusM: Int
    let travelMode: RouteTravelMode

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case startAddress = "start_address"
        case endAddress = "end_address"
        case start
        case end
        case radiusM = "radius_m"
        case travelMode = "travel_mode"
    }
}

struct RouteBuildRequest: Encodable {
    let announcementID: String?
    let polyline: [[Double]]
    let startAddress: String?
    let endAddress: String?
    let distanceMeters: Int?
    let durationSeconds: Int?
    let radiusM: Int
    let travelMode: String

    enum CodingKeys: String, CodingKey {
        case announcementID = "announcement_id"
        case polyline
        case startAddress = "start_address"
        case endAddress = "end_address"
        case distanceMeters = "distance_meters"
        case durationSeconds = "duration_seconds"
        case radiusM = "radius_m"
        case travelMode = "travel_mode"
    }
}

struct RouteDetailsDTO: Decodable {
    let entityID: String
    let startAddress: String
    let endAddress: String
    let distanceMeters: Int
    let durationSeconds: Int
    let distanceText: String
    let durationText: String
    let polyline: [[Double]]
    let tasksByRoute: [TaskByRouteDTO]

    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id"
        case startAddress = "start_address"
        case endAddress = "end_address"
        case distanceMeters = "distance_meters"
        case durationSeconds = "duration_seconds"
        case distanceText = "distance_text"
        case durationText = "duration_text"
        case polyline
        case tasksByRoute = "tasks_by_route"
    }
}

struct TaskByRouteDTO: Decodable, Identifiable {
    let id: String
    let title: String
    let category: String?
    let addressText: String?
    let latitude: Double?
    let longitude: Double?
    let distanceToRouteMeters: Double?
    let priceText: String?
    let previewImageURL: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case addressText = "address_text"
        case latitude
        case longitude
        case distanceToRouteMeters = "distance_to_route_meters"
        case priceText = "price_text"
        case previewImageURL = "preview_image_url"
        case status
    }

    var previewURL: URL? {
        guard let previewImageURL else { return nil }
        return AppURLResolver.resolveAPIURL(from: previewImageURL)
    }

    var distanceLabel: String {
        guard let distanceToRouteMeters else { return "Рядом с маршрутом" }
        let rounded = Int(distanceToRouteMeters.rounded())
        return "\(rounded) м от маршрута"
    }

    var coordinate: GeoPoint? {
        guard let latitude, let longitude else { return nil }
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}
