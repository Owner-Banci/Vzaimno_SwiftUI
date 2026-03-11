import Foundation

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
    let distanceToRouteMeters: Double?
    let priceText: String?
    let previewImageURL: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case addressText = "address_text"
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
}
