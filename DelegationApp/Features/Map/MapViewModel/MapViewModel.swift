import SwiftUI
import YandexMapsMobile
import Foundation

struct MapAdPin: Identifiable {
    let id: String
    let point: YMKPoint
    let label: String
    let announcement: AnnouncementDTO
}

enum MapDisplayMode {
    case real
    case placeholder
}

enum MapDisplayConfig {
    static func defaultMode() -> MapDisplayMode {
        #if DEBUG
        return .real
        #else
        return .real
        #endif
    }
}

struct MapCanvasView: View {
    @Binding var centerPoint: YMKPoint?
    let pins: [MapAdPin]
    let selectedPinID: String?
    let routePolyline: YMKPolyline?
    let shouldFitRoute: Bool
    let onRouteFitted: () -> Void
    let onPinTap: (String) -> Void
    let mode: MapDisplayMode

    var body: some View {
        Group {
            switch mode {
            case .real:
                YandexMapView(
                    centerPoint: $centerPoint,
                    pins: pins,
                    selectedPinID: selectedPinID,
                    routePolyline: routePolyline,
                    shouldFitRoute: shouldFitRoute,
                    onRouteFitted: onRouteFitted,
                    onPinTap: onPinTap
                )
            case .placeholder:
                Rectangle()
                    .fill(Theme.ColorToken.milk)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.ColorToken.textSecondary)
                            Text("Map placeholder")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.ColorToken.textSecondary)
                        }
                    )
            }
        }
    }
}

@MainActor
private final class DrivingRouteService {
    enum RouteError: LocalizedError {
        case unavailable
        case noRoute

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Маршрутизация недоступна"
            case .noRoute:
                return "Маршрут не найден"
            }
        }
    }

    private let router: YMKDrivingRouter?
    private var session: YMKDrivingSession?

    init() {
        YandexMapConfigurator.configureIfNeeded()
        self.router = YMKDirections.sharedInstance()?.createDrivingRouter(withType: .combined)
    }

    func buildRoute(from: YMKPoint, to: YMKPoint) async throws -> YMKPolyline {
        guard let router else { throw RouteError.unavailable }

        let requestPoints = [
            YMKRequestPoint(point: from, type: .waypoint, pointContext: nil, drivingArrivalPointId: nil),
            YMKRequestPoint(point: to, type: .waypoint, pointContext: nil, drivingArrivalPointId: nil),
        ]
        let drivingOptions = YMKDrivingOptions()
        drivingOptions.routesCount = 1
        let vehicleOptions = YMKDrivingVehicleOptions()

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            session?.cancel()
            session = router.requestRoutes(
                with: requestPoints,
                drivingOptions: drivingOptions,
                vehicleOptions: vehicleOptions
            ) { [weak self] routes, error in
                guard !didResume else { return }
                didResume = true
                self?.session = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let route = routes?.first else {
                    continuation.resume(throwing: RouteError.noRoute)
                    return
                }
                continuation.resume(returning: route.geometry)
            }
        }
    }

    func cancel() {
        session?.cancel()
        session = nil
    }
}

@MainActor
final class MapViewModel: ObservableObject {
    // MARK: - Фильтры
    @Published var chips: [String] = [
        "Купить", "Доставить", "Забрать",
        "Помочь", "Перенести", "Другое"
    ]
    @Published var selected: Set<String> = []

    // MARK: - Моковые задачи (пока оставляем)
    @Published var tasks: [TaskItem] = []

    // MARK: - Объявления на карте
    @Published private(set) var announcements: [AnnouncementDTO] = []
    @Published private(set) var pins: [MapAdPin] = []
    @Published var selectedAnnouncement: AnnouncementDTO?
    @Published var selectedPinID: String?
    @Published var routePolyline: YMKPolyline?
    @Published var shouldFitRoute: Bool = false

    // MARK: - Поиск и карта
    @Published var searchText: String = ""
    @Published var centerPoint: YMKPoint?
    @Published var errorMessage: String?

    private let service: TaskService
    private let announcementService: AnnouncementService
    private let searchService: AddressSearchService
    private let routeService: DrivingRouteService
    private var geocodeCache: [String: YMKPoint] = [:]

    init(
        service: TaskService,
        announcementService: AnnouncementService,
        searchService: AddressSearchService = AddressSearchService()
    ) {
        self.service = service
        self.announcementService = announcementService
        self.searchService = searchService
        self.routeService = DrivingRouteService()

        self.tasks = service.loadNearbyTasks()
        self.centerPoint = YMKPoint(latitude: 55.751244, longitude: 37.618423)
    }

    func toggle(_ chip: String) {
        if selected.contains(chip) { selected.remove(chip) }
        else { selected.insert(chip) }
    }

    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            errorMessage = nil
            return
        }

        searchService.searchAddress(query) { [weak self] point in
            DispatchQueue.main.async {
                guard let self else { return }
                if let point {
                    self.centerPoint = point
                    self.errorMessage = nil
                } else {
                    self.errorMessage = "Адрес не найден"
                }
            }
        }
    }

    func reloadPins() async {
        do {
            let list = try await announcementService.publicAnnouncements()
            announcements = list
            pins = list.compactMap { Self.makePin(from: $0) }
        } catch {
            errorMessage = "Не удалось загрузить объявления: \(error.localizedDescription)"
        }
    }

    func selectAnnouncement(pinID: String) async {
        guard let pin = pins.first(where: { $0.id == pinID }) else { return }

        selectedPinID = pinID
        selectedAnnouncement = pin.announcement
        errorMessage = nil

        await buildRouteIfNeeded(for: pin.announcement, expectedPinID: pinID)
    }

    func clearSelection() {
        selectedAnnouncement = nil
        selectedPinID = nil
        clearRoute()
    }

    func consumeRouteFitRequest() {
        shouldFitRoute = false
    }

    private func clearRoute() {
        routeService.cancel()
        routePolyline = nil
        shouldFitRoute = false
    }

    private func buildRouteIfNeeded(for announcement: AnnouncementDTO, expectedPinID: String) async {
        clearRoute()
        guard announcement.category.lowercased() == "delivery" else { return }

        guard let points = await resolveDeliveryRoutePoints(for: announcement) else {
            guard selectedPinID == expectedPinID else { return }
            errorMessage = "Не удалось определить точки маршрута для объявления"
            return
        }

        do {
            let polyline = try await routeService.buildRoute(from: points.start, to: points.end)
            guard selectedPinID == expectedPinID else { return }
            routePolyline = polyline
            shouldFitRoute = true
        } catch {
            guard selectedPinID == expectedPinID else { return }
            errorMessage = "Не удалось построить маршрут: \(error.localizedDescription)"
        }
    }

    private func resolveDeliveryRoutePoints(
        for announcement: AnnouncementDTO
    ) async -> (start: YMKPoint, end: YMKPoint)? {

        let data = announcement.data

        var start: YMKPoint? = Self.extractPoint(from: data, keys: ["pickup_point", "point"])
        if start == nil {
            start = await geocodeFromData(data: data, key: "pickup_address")
        }

        var end: YMKPoint? = Self.extractPoint(from: data, keys: ["dropoff_point"])
        if end == nil {
            end = await geocodeFromData(data: data, key: "dropoff_address")
        }

        guard let start, let end else { return nil }
        return (start, end)
    }
    private func geocodeFromData(data: [String: JSONValue], key: String) async -> YMKPoint? {
        guard
            let address = data[key]?.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !address.isEmpty
        else { return nil }

        if let cached = geocodeCache[address] {
            return cached
        }

        let point = await searchService.searchAddress(address)
        if let point {
            geocodeCache[address] = point
        }
        return point
    }

    private static func makePin(from announcement: AnnouncementDTO) -> MapAdPin? {
        guard let point = extractDisplayPoint(from: announcement) else { return nil }
        return MapAdPin(
            id: announcement.id,
            point: point,
            label: markerLabel(from: announcement),
            announcement: announcement
        )
    }

    private static func extractDisplayPoint(from announcement: AnnouncementDTO) -> YMKPoint? {
        let data = announcement.data
        if announcement.category.lowercased() == "delivery" {
            if let p = extractPoint(from: data, keys: ["pickup_point", "point"]) { return p }
        } else if announcement.category.lowercased() == "help" {
            if let p = extractPoint(from: data, keys: ["help_point", "point"]) { return p }
        }
        return extractPoint(from: data, keys: ["point", "pickup_point", "help_point"])
    }

    private static func extractPoint(
        from data: [String: JSONValue],
        keys: [String]
    ) -> YMKPoint? {
        for key in keys {
            guard let pointVal = data[key]?.objectValue else { continue }
            guard
                let lat = pointVal["lat"]?.doubleValue,
                let lon = pointVal["lon"]?.doubleValue
            else { continue }
            return YMKPoint(latitude: lat, longitude: lon)
        }
        return nil
    }

    private static func markerLabel(from announcement: AnnouncementDTO) -> String {
        if let budget = announcement.data["budget"]?.doubleValue, budget > 0 {
            return "\(Int(budget)) ₽"
        }
        if let budgetText = announcement.data["budget"]?.stringValue,
           let parsed = Double(budgetText.replacingOccurrences(of: ",", with: ".")),
           parsed > 0 {
            return "\(Int(parsed)) ₽"
        }
        return announcement.category.lowercased() == "delivery" ? "Доставка" : "Помощь"
    }
}
