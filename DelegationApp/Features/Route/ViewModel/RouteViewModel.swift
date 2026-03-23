import CoreLocation
import Foundation

#if canImport(YandexMapsMobile)
import YandexMapsMobile
#endif

@MainActor
final class RouteViewModel: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isBuildingRoute: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var emptyMessage: String?

    @Published private(set) var route: RouteDetailsDTO?
    @Published private(set) var tasksByRoute: [TaskByRouteDTO] = []

    @Published private(set) var routePolyline: YMKPolyline?
    @Published private(set) var mapPins: [MapAdPin] = []
    @Published var shouldFitRoute: Bool = false
    @Published var selectedTaskID: String?
    @Published var focusedPoint: YMKPoint?

    @Published var selectedAnnouncement: AnnouncementDTO?

    private let routeService: RouteService
    private let routeGeometryBuilder: RouteGeometryBuilding
    private let announcementService: AnnouncementService
    private let session: SessionStore
    private var announcementCache: [String: AnnouncementDTO] = [:]

    init(
        routeService: RouteService,
        announcementService: AnnouncementService,
        session: SessionStore,
        routeGeometryBuilder: RouteGeometryBuilding? = nil
    ) {
        self.routeService = routeService
        self.routeGeometryBuilder = routeGeometryBuilder ?? AppleDirectionsRouteBuilder()
        self.announcementService = announcementService
        self.session = session
    }

    func load() async {
        guard let token = session.token else {
            showLoggedOutState()
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedRoute = try await buildCurrentRoute(token: token)
            route = fetchedRoute
            tasksByRoute = fetchedRoute.tasksByRoute
            reconcileSelection(with: fetchedRoute.tasksByRoute)
            emptyMessage = nil
            await preloadAnnouncements(for: fetchedRoute.tasksByRoute.map(\.id))
            applyMapData(from: fetchedRoute)
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }

            if error.apiStatusCode == 404 {
                showNoRouteState()
                return
            }

            clearRouteState()
            emptyMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await load()
    }

    func consumeRouteFitRequest() {
        shouldFitRoute = false
    }

    func selectTask(_ task: TaskByRouteDTO) {
        selectedTaskID = task.id
        focusedPoint = resolvedPoint(for: task)
    }

    func selectPin(id: String) {
        guard let task = tasksByRoute.first(where: { $0.id == id }) else { return }
        selectTask(task)
    }

    func openTaskDetails(taskID: String) async {
        if let cached = announcementCache[taskID] {
            selectedAnnouncement = cached
            return
        }

        do {
            let list = try await announcementService.publicAnnouncements()
            var localCache = announcementCache
            for item in list {
                localCache[item.id] = item
            }
            announcementCache = localCache

            if let route {
                applyMapData(from: route)
            }

            if let announcement = announcementCache[taskID] {
                selectedAnnouncement = announcement
            } else {
                errorMessage = "Не удалось открыть объявление: оно больше не активно."
            }
        } catch {
            errorMessage = "Не удалось открыть объявление: \(error.localizedDescription)"
        }
    }

    private func buildCurrentRoute(token: String) async throws -> RouteDetailsDTO {
        guard !isBuildingRoute else {
            if let route {
                return route
            }
            throw RouteGeometryBuildError.unknown
        }

        isBuildingRoute = true
        defer { isBuildingRoute = false }

        let context = try await routeService.fetchMyCurrentRouteContext(token: token)
        let geometry = try await routeGeometryBuilder.buildRoute(
            start: context.start.coordinate,
            end: context.end.coordinate,
            travelMode: context.travelMode
        )

        let request = RouteBuildRequest(
            announcementID: context.entityID,
            polyline: geometry.polyline,
            startAddress: context.startAddress,
            endAddress: context.endAddress,
            distanceMeters: geometry.distanceMeters,
            durationSeconds: geometry.durationSeconds,
            radiusM: context.radiusM,
            travelMode: context.travelMode.apiValue
        )

        return try await routeService.buildRoute(request: request, token: token)
    }

    private func showLoggedOutState() {
        clearRouteState()
        emptyMessage = "Войдите в аккаунт, чтобы увидеть маршрут."
        errorMessage = nil
    }

    private func showNoRouteState() {
        clearRouteState()
        emptyMessage = "Маршрут пока недоступен. Когда вам примут отклик, он появится здесь."
        errorMessage = nil
    }

    private func clearRouteState() {
        route = nil
        tasksByRoute = []
        routePolyline = nil
        mapPins = []
        shouldFitRoute = false
        selectedTaskID = nil
        focusedPoint = nil
    }

    private func preloadAnnouncements(for ids: [String]) async {
        let needed = Set(ids).subtracting(announcementCache.keys)
        guard !needed.isEmpty else { return }

        do {
            let all = try await announcementService.publicAnnouncements()
            for item in all where needed.contains(item.id) {
                announcementCache[item.id] = item
            }
        } catch {
            // Не блокируем экран маршрута из-за фонового префетча.
        }
    }

    private func applyMapData(from details: RouteDetailsDTO) {
        routePolyline = Self.makePolyline(from: details.polyline)
        mapPins = makePins(from: details)
        focusedPoint = selectedTask.flatMap { resolvedPoint(for: $0) }
        shouldFitRoute = routePolyline != nil
    }

    private var selectedTask: TaskByRouteDTO? {
        guard let selectedTaskID else { return nil }
        return tasksByRoute.first(where: { $0.id == selectedTaskID })
    }

    private func reconcileSelection(with tasks: [TaskByRouteDTO]) {
        if let selectedTaskID, tasks.contains(where: { $0.id == selectedTaskID }) {
            return
        }
        selectedTaskID = tasks.first?.id
    }

    private func makePins(from details: RouteDetailsDTO) -> [MapAdPin] {
        var pins = makeRouteEndpointPins(from: details.polyline)
        pins.append(contentsOf: details.tasksByRoute.compactMap(makeTaskPin))
        return pins
    }

    private func makeRouteEndpointPins(from polyline: [[Double]]) -> [MapAdPin] {
        guard
            let startPair = Self.normalizedPair(polyline.first),
            let endPair = Self.normalizedPair(polyline.last)
        else {
            return []
        }

        let markerStub = AnnouncementDTO(
            id: "route-marker",
            user_id: "route",
            category: "route",
            title: "Маршрут",
            status: "active",
            data: [:],
            created_at: "1970-01-01T00:00:00Z"
        )

        return [
            MapAdPin(
                id: "route-start",
                point: YMKPoint(latitude: startPair[0], longitude: startPair[1]),
                label: "Старт",
                announcement: markerStub
            ),
            MapAdPin(
                id: "route-end",
                point: YMKPoint(latitude: endPair[0], longitude: endPair[1]),
                label: "Финиш",
                announcement: markerStub
            ),
        ]
    }

    private func makeTaskPin(from task: TaskByRouteDTO) -> MapAdPin? {
        guard let point = resolvedPoint(for: task) else { return nil }
        let announcement = announcementCache[task.id] ?? Self.makeAnnouncementStub(for: task)

        return MapAdPin(
            id: task.id,
            point: point,
            label: markerLabel(for: task, announcement: announcement),
            announcement: announcement
        )
    }

    private func resolvedPoint(for task: TaskByRouteDTO) -> YMKPoint? {
        if let coordinate = task.coordinate {
            return YMKPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }

        guard let announcement = announcementCache[task.id] else { return nil }
        return Self.extractDisplayPoint(from: announcement)
    }

    private func markerLabel(for task: TaskByRouteDTO, announcement: AnnouncementDTO) -> String {
        if let priceText = task.priceText?.trimmingCharacters(in: .whitespacesAndNewlines), !priceText.isEmpty {
            return priceText
        }
        if let budget = announcement.formattedBudgetText, !budget.isEmpty {
            return budget
        }
        if let category = task.category?.trimmingCharacters(in: .whitespacesAndNewlines), !category.isEmpty {
            return category.capitalized
        }
        return "Задание"
    }

    private static func makeAnnouncementStub(for task: TaskByRouteDTO) -> AnnouncementDTO {
        var data: [String: JSONValue] = [:]

        if let address = task.addressText?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            data["address"] = .string(address)
        }
        if let coordinate = task.coordinate {
            data["point"] = .object([
                "lat": .double(coordinate.latitude),
                "lon": .double(coordinate.longitude),
            ])
        }

        return AnnouncementDTO(
            id: task.id,
            user_id: "route",
            category: task.category ?? "route",
            title: task.title,
            status: task.status ?? "active",
            data: data,
            created_at: "1970-01-01T00:00:00Z"
        )
    }

    private static func normalizedPair(_ raw: [Double]?) -> [Double]? {
        guard let raw, raw.count >= 2 else { return nil }
        let lat = raw[0]
        let lon = raw[1]
        guard (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return [lat, lon]
    }

    private static func makePolyline(from raw: [[Double]]) -> YMKPolyline? {
        #if canImport(YandexMapsMobile)
        guard let builder = YMKPolylineBuilder() else { return nil }
        var pointsCount = 0

        for pair in raw {
            guard let normalized = normalizedPair(pair) else { continue }
            builder.append(YMKPoint(latitude: normalized[0], longitude: normalized[1]))
            pointsCount += 1
        }

        guard pointsCount >= 2 else { return nil }
        return builder.build()
        #else
        return raw.count >= 2 ? YMKPolyline() : nil
        #endif
    }

    private static func extractDisplayPoint(from announcement: AnnouncementDTO) -> YMKPoint? {
        let data = announcement.data

        if announcement.category.lowercased() == "delivery" {
            if let point = extractPoint(from: data, keys: ["pickup_point", "point"]) {
                return point
            }
        } else if announcement.category.lowercased() == "help" {
            if let point = extractPoint(from: data, keys: ["help_point", "point"]) {
                return point
            }
        }

        return extractPoint(from: data, keys: ["point", "pickup_point", "help_point"])
    }

    private static func extractPoint(
        from data: [String: JSONValue],
        keys: [String]
    ) -> YMKPoint? {
        for key in keys {
            guard let pointValue = data[key]?.objectValue else { continue }
            guard
                let lat = pointValue["lat"]?.doubleValue,
                let lon = pointValue["lon"]?.doubleValue
            else { continue }
            return YMKPoint(latitude: lat, longitude: lon)
        }
        return nil
    }
}
