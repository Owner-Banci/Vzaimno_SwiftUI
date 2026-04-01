import CoreLocation
import Foundation
import SwiftUI

#if canImport(YandexMapsMobile)
import YandexMapsMobile
#endif

struct MapAdPin: Identifiable {
    let id: String
    let point: YMKPoint
    let label: String
    let announcement: AnnouncementDTO
}

enum MapDisplayMode {
    case apple
    case yandex
    case placeholder
}

enum MapDisplayConfig {
    static func defaultMode() -> MapDisplayMode {
        .apple
    }
}

enum MapContentMode {
    case map
    case list
}

@MainActor
final class MapViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet {
            rebuildPresentations()
        }
    }
    @Published var filters = AnnouncementSearchFilters() {
        didSet {
            rebuildPresentations()
        }
    }
    @Published var contentMode: MapContentMode = .map
    @Published var isFiltersPresented: Bool = false
    @Published var sheetDetent: MapSheetDetent = .peek
    @Published var sortMode: MapTaskSortMode = .smart {
        didSet {
            rebuildPresentations()
        }
    }

    @Published var routeStartAddress: String = ""
    @Published var routeEndAddress: String = ""
    @Published var isBuildingRoute: Bool = false
    @Published var routeErrorMessage: String?

    @Published private(set) var announcements: [AnnouncementDTO] = []
    @Published private(set) var filteredTasks: [MapTaskPresentation] = []
    @Published var selectedAnnouncement: AnnouncementDTO?
    @Published var selectedAnnouncementID: String?

    @Published var visibleCenterCoordinate: CLLocationCoordinate2D? {
        didSet {
            guard shouldRefresh(for: oldValue, newValue: visibleCenterCoordinate) else { return }
            rebuildPresentations()
        }
    }
    @Published var cameraCommand: AppleTaskMapCameraCommand?
    @Published var shouldFitRoute: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var routeState: MapTaskRouteState?

    let service: TaskService
    private let announcementService: AnnouncementService
    private let searchService: AddressSearchService
    private let routeGeometryBuilder: RouteGeometryBuilding
    private let locationProvider: MapUserLocationProvider

    private var autoRefreshTask: Task<Void, Never>?

    init(
        service: TaskService,
        announcementService: AnnouncementService,
        searchService: AddressSearchService = AddressSearchService(),
        routeGeometryBuilder: RouteGeometryBuilding? = nil,
        locationProvider: MapUserLocationProvider = MapUserLocationProvider()
    ) {
        self.service = service
        self.announcementService = announcementService
        self.searchService = searchService
        self.routeGeometryBuilder = routeGeometryBuilder ?? AppleDirectionsRouteBuilder()
        self.locationProvider = locationProvider
        self.visibleCenterCoordinate = CLLocationCoordinate2D(latitude: 55.751244, longitude: 37.618423)

        self.locationProvider.onCoordinate = { [weak self] coordinate in
            guard let self else { return }
            self.visibleCenterCoordinate = coordinate
            self.cameraCommand = AppleTaskMapCameraCommand(kind: .center(coordinate))
        }
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    var quickFilters: [MapQuickActionFilter] {
        MapQuickActionFilter.allCases
    }

    var isListMode: Bool {
        contentMode == .list
    }

    var surfaceToggleSystemImage: String {
        isListMode ? "map" : "list.bullet.rectangle.portrait"
    }

    var filterButtonTitle: String {
        if filters.advancedFilterCount > 0 {
            return "Фильтры • \(filters.advancedFilterCount)"
        }
        if hasRoute {
            return "Маршрут и фильтры"
        }
        return "Фильтры и маршрут"
    }

    var filterButtonSubtitle: String {
        if let routeMatchedCountText {
            return routeMatchedCountText
        }
        if filters.hasAnyAdvancedFilter {
            return "Точная настройка списка и карты"
        }
        return "Откройте полный набор параметров"
    }

    var displayedCountText: String {
        "\(filteredTasks.count.formatted(.number.grouping(.automatic))) из \(announcements.count.formatted(.number.grouping(.automatic))) объявлений"
    }

    var routeMatchedCountText: String? {
        guard let routeState, routeState.matchedCount > 0 else { return nil }
        return "Из них \(routeState.matchedCount.formatted(.number.grouping(.automatic))) задач по пути"
    }

    var routeMetaText: String? {
        guard let routeState else { return nil }
        let distanceKm = Double(routeState.distanceMeters) / 1000
        let minutes = max(1, Int((Double(routeState.durationSeconds) / 60).rounded()))
        return String(format: "%.1f км • %d мин", distanceKm, minutes)
    }

    var hasRoute: Bool {
        routeState != nil
    }

    var previewTasks: [MapTaskPresentation] {
        Array(filteredTasks.prefix(sheetDetent == .half ? 3 : 5))
    }

    var mappedPins: [MapAdPin] {
        filteredTasks.compactMap { task in
            guard let coordinate = task.coordinate else { return nil }
            return MapAdPin(
                id: task.id,
                point: YMKPoint(latitude: coordinate.latitude, longitude: coordinate.longitude),
                label: task.markerText,
                announcement: task.announcement
            )
        }
    }

    func reloadPins() async {
        do {
            let list = try await announcementService.publicAnnouncements()
            announcements = list
            refreshSelection()
            rebuildPresentations()
        } catch {
            errorMessage = "Не удалось загрузить объявления: \(error.localizedDescription)"
        }
    }

    func startAutoRefresh() {
        guard autoRefreshTask == nil else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled, let self else { break }
                await self.reloadPins()
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

    func performSearch() {
        rebuildPresentations()
    }

    func toggleQuickFilter(_ filter: MapQuickActionFilter) {
        filters.toggleAction(filter)
    }

    func toggleContentMode() {
        contentMode = isListMode ? .map : .list
    }

    func openListMode() {
        contentMode = .list
    }

    func showMapMode() {
        contentMode = .map
    }

    func presentFilters() {
        isFiltersPresented = true
    }

    func dismissFilters() {
        isFiltersPresented = false
    }

    func setSheetDetent(_ detent: MapSheetDetent) {
        sheetDetent = detent
    }

    func selectAnnouncement(pinID: String) async {
        guard let task = filteredTasks.first(where: { $0.id == pinID }) else { return }
        selectPresentation(task, presentDetails: true)
    }

    func selectAnnouncementFromList(_ task: MapTaskPresentation) {
        selectPresentation(task, presentDetails: true)
    }

    func highlightAnnouncement(_ task: MapTaskPresentation) {
        selectPresentation(task, presentDetails: false)
    }

    func clearSelection() {
        selectedAnnouncement = nil
        selectedAnnouncementID = nil
    }

    func zoomIn() {
        cameraCommand = AppleTaskMapCameraCommand(kind: .zoomIn)
    }

    func zoomOut() {
        cameraCommand = AppleTaskMapCameraCommand(kind: .zoomOut)
    }

    func centerOnUser() {
        locationProvider.requestLocation()
    }

    func consumeRouteFitRequest() {
        shouldFitRoute = false
    }

    func consumeCameraCommand(_ id: UUID) {
        guard cameraCommand?.id == id else { return }
        cameraCommand = nil
    }

    func buildRoute() async {
        let startAddress = routeStartAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let endAddress = routeEndAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !startAddress.isEmpty, !endAddress.isEmpty else {
            routeErrorMessage = "Заполните адрес отправления и прибытия"
            return
        }

        isBuildingRoute = true
        routeErrorMessage = nil
        defer { isBuildingRoute = false }

        guard let startPoint = await searchService.searchAddress(startAddress) else {
            routeErrorMessage = "Не удалось найти стартовый адрес"
            return
        }

        guard let endPoint = await searchService.searchAddress(endAddress) else {
            routeErrorMessage = "Не удалось найти конечный адрес"
            return
        }

        let startCoordinate = CLLocationCoordinate2D(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let endCoordinate = CLLocationCoordinate2D(latitude: endPoint.latitude, longitude: endPoint.longitude)

        do {
            let geometry = try await routeGeometryBuilder.buildRoute(
                start: startCoordinate,
                end: endCoordinate,
                travelMode: .driving
            )
            let coordinates = geometry.polyline.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
            }
            let matched = MapTaskRouteMatcher.matchedDistances(
                announcements: announcements,
                routeCoordinates: coordinates
            )
            routeState = MapTaskRouteState(
                startAddress: startAddress,
                endAddress: endAddress,
                startCoordinate: startCoordinate,
                endCoordinate: endCoordinate,
                coordinates: coordinates,
                distanceMeters: geometry.distanceMeters,
                durationSeconds: geometry.durationSeconds,
                matchedDistances: matched
            )
            shouldFitRoute = true
            rebuildPresentations()
        } catch {
            routeErrorMessage = error.localizedDescription
        }
    }

    func clearRoute() {
        routeState = nil
        routeErrorMessage = nil
        if filters.onlyOnRoute {
            filters.onlyOnRoute = false
        } else {
            rebuildPresentations()
        }
    }

    private func rebuildPresentations() {
        let mapped = MapTaskPresentationMapper.map(
            announcements: announcements,
            filters: filters,
            query: searchText,
            referenceCoordinate: visibleCenterCoordinate,
            routeState: routeState
        )
        filteredTasks = MapTaskPresentationMapper.sorted(
            presentations: mapped,
            sortMode: sortMode
        )

        if let selectedAnnouncementID,
           let refreshed = filteredTasks.first(where: { $0.id == selectedAnnouncementID }) {
            selectedAnnouncement = refreshed.announcement
        } else if selectedAnnouncementID != nil,
                  !announcements.contains(where: { $0.id == selectedAnnouncementID }) {
            clearSelection()
        }
    }

    private func refreshSelection() {
        guard let selectedAnnouncementID else { return }
        guard let refreshed = announcements.first(where: { $0.id == selectedAnnouncementID }) else {
            clearSelection()
            return
        }
        selectedAnnouncement = refreshed
    }

    private func selectPresentation(_ task: MapTaskPresentation, presentDetails: Bool) {
        selectedAnnouncementID = task.id
        cameraCommand = task.coordinate.map { AppleTaskMapCameraCommand(kind: .center($0)) }
        if presentDetails {
            selectedAnnouncement = task.announcement
        }
        errorMessage = nil
    }

    private func shouldRefresh(
        for oldValue: CLLocationCoordinate2D?,
        newValue: CLLocationCoordinate2D?
    ) -> Bool {
        guard let oldValue, let newValue else { return true }
        let oldLocation = CLLocation(latitude: oldValue.latitude, longitude: oldValue.longitude)
        let newLocation = CLLocation(latitude: newValue.latitude, longitude: newValue.longitude)
        return oldLocation.distance(from: newLocation) > 150
    }
}

final class MapUserLocationProvider: NSObject {
    var onCoordinate: ((CLLocationCoordinate2D) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        default:
            manager.requestLocation()
        }
    }
}

extension MapUserLocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onCoordinate?(coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Не блокируем карту из-за геолокации.
    }
}
