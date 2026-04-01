import CoreLocation
import Foundation

@MainActor
final class RouteViewModel: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isBuildingRoute: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var emptyMessage: String?

    @Published private(set) var route: RouteDetailsDTO?
    @Published private(set) var tasksByRoute: [TaskByRouteDTO] = []

    @Published var selectedTaskID: String?
    @Published var focusedCoordinate: CLLocationCoordinate2D?
    @Published var shouldFitRoute: Bool = false
    @Published var selectedAnnouncement: AnnouncementDTO?

    private let routeService: RouteService
    private let routeGeometryBuilder: RouteGeometryBuilding
    private let announcementService: AnnouncementService
    private let session: SessionStore

    private var announcementCache: [String: AnnouncementDTO] = [:]
    private var autoRefreshTask: Task<Void, Never>?

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

    deinit {
        autoRefreshTask?.cancel()
    }

    var routeCoordinates: [CLLocationCoordinate2D] {
        route?.polylineCoordinates ?? []
    }

    var mapPins: [RouteMapPin] {
        guard let route else { return [] }

        var pins: [RouteMapPin] = []

        if let start = route.polylineCoordinates.first {
            pins.append(
                RouteMapPin(
                    id: "route-start",
                    title: "Старт",
                    subtitle: route.startAddress,
                    latitude: start.latitude,
                    longitude: start.longitude,
                    kind: .start
                )
            )
        }

        if let end = route.polylineCoordinates.last {
            pins.append(
                RouteMapPin(
                    id: "route-end",
                    title: "Финиш",
                    subtitle: route.endAddress,
                    latitude: end.latitude,
                    longitude: end.longitude,
                    kind: .end
                )
            )
        }

        pins.append(
            contentsOf: tasksByRoute.compactMap { task in
                guard let coordinate = task.coordinate else { return nil }
                return RouteMapPin(
                    id: task.id,
                    title: task.title,
                    subtitle: task.addressText,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    kind: .recommendedTask
                )
            }
        )

        return pins
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
            applyRoute(fetchedRoute)
            if let selectedAnnouncement,
               !fetchedRoute.tasksByRoute.contains(where: { $0.id == selectedAnnouncement.id }) {
                self.selectedAnnouncement = nil
            }
            emptyMessage = nil
            await preloadAnnouncements(for: fetchedRoute.tasksByRoute.map(\.id))
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

    func startAutoRefresh() {
        guard autoRefreshTask == nil else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled, let self else { break }
                await self.load()
            }

            await MainActor.run {
                self?.autoRefreshTask = nil
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    func consumeRouteFitRequest() {
        shouldFitRoute = false
    }

    func selectTask(_ task: TaskByRouteDTO) {
        selectedTaskID = task.id
        focusedCoordinate = task.coordinate
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
        selectedTaskID = nil
        focusedCoordinate = nil
        shouldFitRoute = false
        selectedAnnouncement = nil
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
            // Не блокируем экран маршрута из-за фоновой подгрузки карточек.
        }
    }

    private func applyRoute(_ details: RouteDetailsDTO) {
        route = details
        tasksByRoute = details.tasksByRoute
        reconcileSelection(with: details.tasksByRoute)
        focusedCoordinate = selectedTask?.coordinate
        shouldFitRoute = routeCoordinates.count >= 2
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
}
