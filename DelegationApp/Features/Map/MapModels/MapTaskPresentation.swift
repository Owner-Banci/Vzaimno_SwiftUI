import CoreLocation
import Foundation
import MapKit

enum MapTaskMarkerKind: Hashable {
    case regular
    case onRoute
    case selected
}

struct MapTaskRouteState {
    let startAddress: String
    let endAddress: String
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Int
    let durationSeconds: Int
    let matchedDistances: [String: Double]

    var matchedCount: Int {
        matchedDistances.count
    }
}

struct MapTaskPresentation: Identifiable {
    let id: String
    let announcement: AnnouncementDTO
    let coordinate: CLLocationCoordinate2D?
    let title: String
    let subtitle: String
    let budgetText: String
    let previewURL: URL?
    let tags: [String]
    let actionTitle: String
    let markerText: String
    let routeDistanceMeters: Double?
    let distanceFromReferenceMeters: Double?
    let estimatedTaskMinutes: Int?
    let isOnRoute: Bool
    let sortBudgetValue: Int
    let urgencyRank: Int

    var markerKind: MapTaskMarkerKind {
        if isOnRoute {
            return .onRoute
        }
        return .regular
    }

    var distanceLabel: String {
        if let routeDistanceMeters {
            let rounded = Int(routeDistanceMeters.rounded())
            return "\(rounded) м от маршрута"
        }
        if let distanceFromReferenceMeters {
            if distanceFromReferenceMeters >= 1000 {
                let km = distanceFromReferenceMeters / 1000
                return String(format: "%.1f км рядом", km)
            }
            return "\(Int(distanceFromReferenceMeters.rounded())) м рядом"
        }
        if let estimatedTaskMinutes {
            return "~\(estimatedTaskMinutes) мин"
        }
        return "Без маршрута"
    }

    var etaLabel: String? {
        guard let estimatedTaskMinutes else { return nil }
        return "\(estimatedTaskMinutes) мин на задачу"
    }
}

enum MapTaskPresentationMapper {
    static func map(
        announcements: [AnnouncementDTO],
        filters: AnnouncementSearchFilters,
        query: String,
        referenceCoordinate: CLLocationCoordinate2D?,
        routeState: MapTaskRouteState?
    ) -> [MapTaskPresentation] {
        let routeDistances = routeState?.matchedDistances ?? [:]

        return announcements.compactMap { announcement in
            let routeDistance = routeDistances[announcement.id]
            guard filters.matches(
                announcement: announcement,
                query: query,
                routeDistanceMeters: routeDistance
            ) else {
                return nil
            }

            return makePresentation(
                announcement: announcement,
                referenceCoordinate: referenceCoordinate,
                routeDistanceMeters: routeDistance
            )
        }
    }

    static func makePresentation(
        announcement: AnnouncementDTO,
        referenceCoordinate: CLLocationCoordinate2D?,
        routeDistanceMeters: Double?
    ) -> MapTaskPresentation {
        let structured = announcement.structuredData
        let coordinate = announcement.mapCoordinate
        let budget = announcement.formattedBudgetText ?? "Цена не указана"
        let distanceFromReference = coordinate.flatMap { coordinate in
            referenceCoordinate.map {
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    .distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
            }
        }
        let tags = announcement.structuredBadges
        let actionTitle = structured.actionType?.title ?? "Объявление"
        let markerText = announcement.formattedBudgetText ?? actionTitle

        return MapTaskPresentation(
            id: announcement.id,
            announcement: announcement,
            coordinate: coordinate,
            title: announcement.title,
            subtitle: announcement.shortStructuredSubtitle,
            budgetText: budget,
            previewURL: announcement.previewImageURL,
            tags: Array(tags.prefix(4)),
            actionTitle: actionTitle,
            markerText: markerText,
            routeDistanceMeters: routeDistanceMeters,
            distanceFromReferenceMeters: distanceFromReference,
            estimatedTaskMinutes: structured.estimatedTaskMinutes,
            isOnRoute: routeDistanceMeters != nil,
            sortBudgetValue: max(
                announcement.budgetMaxValue ?? 0,
                announcement.budgetMinValue ?? 0,
                announcement.budgetValue ?? 0
            ),
            urgencyRank: urgencyRank(for: structured.urgency)
        )
    }

    static func sorted(
        presentations: [MapTaskPresentation],
        sortMode: MapTaskSortMode
    ) -> [MapTaskPresentation] {
        presentations.sorted { lhs, rhs in
            switch sortMode {
            case .smart:
                return smartCompare(lhs: lhs, rhs: rhs)
            case .budgetHigh:
                if lhs.sortBudgetValue != rhs.sortBudgetValue {
                    return lhs.sortBudgetValue > rhs.sortBudgetValue
                }
                return smartCompare(lhs: lhs, rhs: rhs)
            case .urgentFirst:
                if lhs.urgencyRank != rhs.urgencyRank {
                    return lhs.urgencyRank < rhs.urgencyRank
                }
                return smartCompare(lhs: lhs, rhs: rhs)
            }
        }
    }

    private static func smartCompare(lhs: MapTaskPresentation, rhs: MapTaskPresentation) -> Bool {
        if lhs.isOnRoute != rhs.isOnRoute {
            return lhs.isOnRoute && !rhs.isOnRoute
        }

        let lhsRoute = lhs.routeDistanceMeters ?? .greatestFiniteMagnitude
        let rhsRoute = rhs.routeDistanceMeters ?? .greatestFiniteMagnitude
        if lhsRoute != rhsRoute {
            return lhsRoute < rhsRoute
        }

        let lhsDuration = lhs.estimatedTaskMinutes ?? Int.max
        let rhsDuration = rhs.estimatedTaskMinutes ?? Int.max
        if lhsDuration != rhsDuration {
            return lhsDuration < rhsDuration
        }

        if lhs.sortBudgetValue != rhs.sortBudgetValue {
            return lhs.sortBudgetValue > rhs.sortBudgetValue
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func urgencyRank(for urgency: AnnouncementStructuredData.Urgency?) -> Int {
        switch urgency {
        case .some(.now): return 0
        case .some(.today): return 1
        case .some(.scheduled): return 2
        case .some(.flexible), .none: return 3
        }
    }
}

enum MapTaskRouteMatcher {
    static func matchedDistances(
        announcements: [AnnouncementDTO],
        routeCoordinates: [CLLocationCoordinate2D],
        maxDistanceMeters: Double = 450
    ) -> [String: Double] {
        guard routeCoordinates.count >= 2 else { return [:] }

        let polyline = MKPolyline(coordinates: routeCoordinates, count: routeCoordinates.count)
        var result: [String: Double] = [:]

        for announcement in announcements {
            guard let coordinate = announcement.mapCoordinate else { continue }
            let distance = distanceFromCoordinate(coordinate, to: polyline)
            guard distance <= maxDistanceMeters else { continue }
            result[announcement.id] = distance
        }

        return result
    }

    private static func distanceFromCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        to polyline: MKPolyline
    ) -> CLLocationDistance {
        let target = MKMapPoint(coordinate)
        var coordinates = Array(repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))

        guard coordinates.count >= 2 else { return .greatestFiniteMagnitude }

        var minDistance = CLLocationDistance.greatestFiniteMagnitude
        for index in 0..<(coordinates.count - 1) {
            let start = MKMapPoint(coordinates[index])
            let end = MKMapPoint(coordinates[index + 1])
            let distance = distanceFromPoint(target, toSegmentFrom: start, to: end)
            minDistance = min(minDistance, distance)
        }

        return minDistance
    }

    private static func distanceFromPoint(
        _ point: MKMapPoint,
        toSegmentFrom start: MKMapPoint,
        to end: MKMapPoint
    ) -> CLLocationDistance {
        let dx = end.x - start.x
        let dy = end.y - start.y

        guard dx != 0 || dy != 0 else {
            return point.distance(to: start)
        }

        let t = max(
            0,
            min(
                1,
                ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)
            )
        )

        let projection = MKMapPoint(x: start.x + t * dx, y: start.y + t * dy)
        return point.distance(to: projection)
    }
}

private extension MKMapPoint {
    func distance(to point: MKMapPoint) -> CLLocationDistance {
        let first = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let second = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
        return first.distance(from: second)
    }
}
