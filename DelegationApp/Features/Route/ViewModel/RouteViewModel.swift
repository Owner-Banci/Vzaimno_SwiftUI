import Foundation

#if canImport(YandexMapsMobile)
import YandexMapsMobile
#endif

@MainActor
final class RouteViewModel: ObservableObject {
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var emptyMessage: String?

    @Published private(set) var route: RouteDetailsDTO?
    @Published private(set) var tasksByRoute: [TaskByRouteDTO] = []

    @Published private(set) var routePolyline: YMKPolyline?
    @Published private(set) var mapPins: [MapAdPin] = []
    @Published var shouldFitRoute: Bool = false

    @Published var selectedAnnouncement: AnnouncementDTO?

    private let routeService: RouteService
    private let announcementService: AnnouncementService
    private let session: SessionStore
    private var announcementCache: [String: AnnouncementDTO] = [:]

    init(
        routeService: RouteService,
        announcementService: AnnouncementService,
        session: SessionStore
    ) {
        self.routeService = routeService
        self.announcementService = announcementService
        self.session = session
    }

    func load() async {
        guard let token = session.token else {
            route = nil
            tasksByRoute = []
            routePolyline = nil
            mapPins = []
            emptyMessage = "Войдите в аккаунт, чтобы увидеть маршрут."
            errorMessage = nil
            return
        }

        if isLoading {
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await routeService.fetchMyCurrentRoute(token: token)
            route = fetched
            tasksByRoute = fetched.tasksByRoute
            emptyMessage = nil
            applyMapData(from: fetched)
            await preloadAnnouncements(for: fetched.tasksByRoute.map(\.id))
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }

            if error.apiStatusCode == 404 {
                route = nil
                tasksByRoute = []
                routePolyline = nil
                mapPins = []
                shouldFitRoute = false
                emptyMessage = "Маршрут пока недоступен. Когда вам примут отклик, он появится здесь."
                errorMessage = nil
                return
            }

            route = nil
            tasksByRoute = []
            routePolyline = nil
            mapPins = []
            shouldFitRoute = false
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
        mapPins = Self.makePins(from: details.polyline)
        shouldFitRoute = routePolyline != nil
    }

    private static func makePins(from polyline: [[Double]]) -> [MapAdPin] {
        guard
            let startPair = normalizedPair(polyline.first),
            let endPair = normalizedPair(polyline.last)
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
}
