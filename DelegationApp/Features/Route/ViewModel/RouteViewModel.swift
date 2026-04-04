import CoreLocation
import Foundation
import MapKit

@MainActor
final class RouteViewModel: ObservableObject {
    enum Role: String, CaseIterable, Identifiable {
        case performer
        case customer

        var id: String { rawValue }

        var title: String {
            switch self {
            case .performer: return "Исполнитель"
            case .customer: return "Заказчик"
            }
        }
    }

    enum TaskKind {
        case primary
        case acceptedAdditional
        case previewBranch
        case customerObserved

        var badgeTitle: String {
            switch self {
            case .primary: return "Основное"
            case .acceptedAdditional: return "По пути"
            case .previewBranch: return "Ветка"
            case .customerObserved: return "Наблюдение"
            }
        }
    }

    enum TaskStage: Int, CaseIterable, Identifiable {
        case accepted
        case heading
        case onSite
        case doing
        case finishing
        case completed

        var id: Int { rawValue }
    }

    struct Metric: Identifiable {
        let id: String
        let title: String
        let value: String
    }

    struct TaskCard: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let detailsText: String
        let addressText: String?
        let priceText: String?
        let badgeTitle: String
        let kind: TaskKind
        let coordinate: CLLocationCoordinate2D?
        let stage: TaskStage?
        let nextSelectableStage: TaskStage?
        let stageTitles: [String]
        let detourText: String?
        let previewSummary: String?
        let canUpdateStatus: Bool
        let canAcceptToRoute: Bool
        let canRemoveFromRoute: Bool
        let announcementID: String?
    }

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isRebuildingRoute: Bool = false
    @Published var errorMessage: String?
    @Published var selectedRole: Role = .performer
    @Published var focusedCoordinate: CLLocationCoordinate2D?
    @Published var shouldFitRoute: Bool = false
    @Published var selectedAnnouncement: AnnouncementDTO?
    @Published private var renderTrigger: Int = 0

    private let routeService: RouteService
    private let routeGeometryBuilder: RouteGeometryBuilding
    private let announcementService: AnnouncementService
    private let session: SessionStore
    private let locationProvider: MapUserLocationProvider

    private var announcementCache: [String: AnnouncementDTO] = [:]
    private var publicAnnouncements: [AnnouncementDTO] = []
    private var myAnnouncements: [AnnouncementDTO] = []
    private var autoRefreshTask: Task<Void, Never>?

    private var routeContext: RouteContextDTO?
    private var baseRoute: RouteDetailsDTO?
    private var performerMainCoordinates: [CLLocationCoordinate2D] = []
    private var performerDistanceMeters: Int = 0
    private var performerDurationSeconds: Int = 0
    private var performerBranchPolylines: [RouteMapPolyline] = []
    private var performerRouteNote: String?
    private var performerUnavailableMessage: String?

    private var customerRouteCache: [String: RouteGeometry] = [:]
    private var customerRouteContexts: [String: RouteContextDTO] = [:]
    private var customerTrackedTaskIDs: [String] = []
    private var customerApproximateRouteTaskIDs: Set<String> = []
    private var customerUnavailableMessage: String?

    private var acceptedAdditionalTaskIDs: [String] = []
    private var taskStages: [String: TaskStage] = [:]
    private var expandedTaskIDs: Set<String> = []
    private var selectedPerformerTaskID: String?
    private var selectedCustomerTaskID: String?
    private var currentUserCoordinate: CLLocationCoordinate2D?

    init(
        routeService: RouteService,
        announcementService: AnnouncementService,
        session: SessionStore,
        routeGeometryBuilder: RouteGeometryBuilding? = nil,
        locationProvider: MapUserLocationProvider = MapUserLocationProvider()
    ) {
        self.routeService = routeService
        self.routeGeometryBuilder = routeGeometryBuilder ?? AppleDirectionsRouteBuilder()
        self.announcementService = announcementService
        self.session = session
        self.locationProvider = locationProvider

        self.locationProvider.onCoordinate = { [weak self] coordinate in
            guard let self else { return }
            self.currentUserCoordinate = coordinate
        }
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    var hasRenderableContent: Bool {
        switch selectedRole {
        case .performer:
            return performerHasContent
        case .customer:
            return customerHasContent
        }
    }

    var selectedTaskID: String? {
        switch selectedRole {
        case .performer:
            return selectedPerformerTaskID
        case .customer:
            return selectedCustomerTaskID
        }
    }

    var screenTitle: String { "Маршрут" }

    var canOpenInAppleMaps: Bool {
        selectedRole == .performer && performerNavigationMapItems.count >= 2
    }

    var roleDescription: String {
        switch selectedRole {
        case .performer:
            if performerHasContent {
                return "Основной маршрут, ветки по пути и управление статусами собраны в одном месте."
            }
            return performerUnavailableMessage ?? "Когда появится активное задание, здесь соберётся маршрут исполнителя."
        case .customer:
            if customerHasContent {
                return "Показываем только ваши задачи и только основной маршрут без чужих ответвлений."
            }
            return customerUnavailableMessage ?? "Когда ваши задания перейдут в выполнение, они появятся в режиме заказчика."
        }
    }

    var mapNote: String? {
        switch selectedRole {
        case .performer:
            return performerRouteNote
        case .customer:
            if let selectedCustomerTaskID,
               customerApproximateRouteTaskIDs.contains(selectedCustomerTaskID) {
                return "Основной маршрут задачи показан приблизительно: Apple Maps не вернул точную геометрию."
            }
            return nil
        }
    }

    var currentMetrics: [Metric] {
        switch selectedRole {
        case .performer:
            return performerMetrics
        case .customer:
            return customerMetrics
        }
    }

    var visibleTasks: [TaskCard] {
        switch selectedRole {
        case .performer:
            return performerTasks
        case .customer:
            return customerTasks
        }
    }

    var mapMarkers: [RouteMapMarker] {
        switch selectedRole {
        case .performer:
            return performerMarkers
        case .customer:
            return customerMarkers
        }
    }

    var mapPolylines: [RouteMapPolyline] {
        switch selectedRole {
        case .performer:
            var lines: [RouteMapPolyline] = []
            if performerMainCoordinates.count >= 2 {
                lines.append(
                    RouteMapPolyline(
                        id: "performer-main-route",
                        coordinates: performerMainCoordinates,
                        kind: .main
                    )
                )
            }
            lines.append(contentsOf: performerBranchPolylines)
            return lines

        case .customer:
            guard let selectedCustomerTaskID,
                  let geometry = customerRouteCache[selectedCustomerTaskID] else {
                return []
            }
            let coordinates = geometry.polyline.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
            }
            guard coordinates.count >= 2 else { return [] }
            return [
                RouteMapPolyline(
                    id: "customer-main-route-\(selectedCustomerTaskID)",
                    coordinates: coordinates,
                    kind: .customerMain
                )
            ]
        }
    }

    var emptyMessage: String {
        switch selectedRole {
        case .performer:
            return performerUnavailableMessage ?? "У исполнителя пока нет активного маршрута."
        case .customer:
            return customerUnavailableMessage ?? "У заказчика пока нет задач в выполнении."
        }
    }

    func load(autoRefresh: Bool = false) async {
        guard let token = session.token else {
            clearAllState()
            performerUnavailableMessage = "Войдите в аккаунт, чтобы увидеть маршрут."
            customerUnavailableMessage = "Войдите в аккаунт, чтобы увидеть выполнение ваших задач."
            return
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        locationProvider.requestLocation()

        defer { isLoading = false }

        switch selectedRole {
        case .performer:
            performerRouteNote = nil
            performerUnavailableMessage = nil
            await loadPerformerData(token: token, autoRefresh: autoRefresh)
        case .customer:
            customerUnavailableMessage = nil
            await loadCustomerData(token: token)
        }

        ensureSelections()
        if selectedRole == .customer {
            await ensureCustomerRouteBuiltIfNeeded()
        }
        updateFocusForCurrentSelection(fitMap: !autoRefresh)
        invalidateView()
    }

    func refresh() async {
        await load(autoRefresh: false)
    }

    func startAutoRefresh() {
        guard autoRefreshTask == nil else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let refreshInterval: UInt64 = await MainActor.run {
                    switch self.selectedRole {
                    case .customer:
                        return self.customerTrackedTaskIDs.isEmpty ? 15_000_000_000 : 5_000_000_000
                    case .performer:
                        return self.routeContext == nil ? 45_000_000_000 : 15_000_000_000
                    }
                }
                try? await Task.sleep(nanoseconds: refreshInterval)
                guard !Task.isCancelled else { break }
                await self.load(autoRefresh: true)
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

    func isExpanded(taskID: String) -> Bool {
        expandedTaskIDs.contains(taskID)
    }

    func toggleExpansion(for taskID: String) {
        if expandedTaskIDs.contains(taskID) {
            expandedTaskIDs.remove(taskID)
        } else {
            expandedTaskIDs.insert(taskID)
        }
        invalidateView()
    }

    func switchRole(_ role: Role) {
        selectedRole = role
        if role == .customer {
            if selectedCustomerTaskID == nil {
                selectedCustomerTaskID = customerTasks.first?.id
            }
            Task { [weak self] in
                await self?.load(autoRefresh: false)
            }
        } else {
            if selectedPerformerTaskID == nil {
                selectedPerformerTaskID = performerTasks.first?.id
            }
            Task { [weak self] in
                await self?.load(autoRefresh: false)
            }
        }
    }

    func selectTask(_ task: TaskCard, fitMap: Bool = false) {
        switch selectedRole {
        case .performer:
            selectedPerformerTaskID = task.id
        case .customer:
            selectedCustomerTaskID = task.id
            Task { [weak self] in
                await self?.ensureCustomerRouteBuiltIfNeeded()
            }
        }

        focusedCoordinate = task.coordinate
        if fitMap {
            shouldFitRoute = true
        }
        invalidateView()
    }

    func selectPin(id: String) {
        guard let task = visibleTasks.first(where: { $0.id == id }) else { return }
        selectTask(task)
        expandedTaskIDs.insert(id)
    }

    func openTaskDetails(taskID: String) async {
        if let cached = announcementCache[taskID] {
            selectedAnnouncement = cached
            return
        }

        if let token = session.token {
            do {
                let announcement = try await announcementService.fetchAnnouncement(
                    token: token,
                    announcementId: taskID
                )
                mergeAnnouncement(announcement)
                selectedAnnouncement = announcement
                return
            } catch {
                if error.isUnauthorizedResponse {
                    await session.logout()
                    return
                }
            }
        }

        do {
            let publicList = try await announcementService.publicAnnouncements()
            for item in publicList {
                announcementCache[item.id] = item
            }

            if let cached = announcementCache[taskID] {
                selectedAnnouncement = cached
                return
            }

            if let token = session.token {
                let myList = try await announcementService.myAnnouncements(token: token)
                for item in myList {
                    announcementCache[item.id] = item
                }
            }

            if let cached = announcementCache[taskID] {
                selectedAnnouncement = cached
            } else {
                errorMessage = "Не удалось открыть объявление: оно больше не активно."
            }
        } catch {
            errorMessage = "Не удалось открыть объявление: \(error.localizedDescription)"
        }
    }

    func acceptPreviewTask(_ taskID: String) async {
        guard !acceptedAdditionalTaskIDs.contains(taskID) else { return }
        guard acceptedAdditionalTaskIDs.count < 2 else {
            errorMessage = "Можно принять не больше двух дополнительных задач по пути."
            return
        }

        acceptedAdditionalTaskIDs.append(taskID)
        await rebuildPerformerRouteTree()

        if let accepted = performerTasks.first(where: { $0.id == taskID }) {
            selectTask(accepted, fitMap: true)
            expandedTaskIDs.insert(taskID)
        }
        invalidateView()
    }

    func removeAcceptedTask(_ taskID: String) async {
        acceptedAdditionalTaskIDs.removeAll { $0 == taskID }
        await rebuildPerformerRouteTree()
        ensureSelections()
        invalidateView()
    }

    func updateStage(taskID: String, stage: TaskStage) async {
        let currentStage = resolvedStage(for: taskID, fallbackStatus: announcementCache[taskID]?.status)
        let allowedStage = nextSelectableStage(after: currentStage)

        if currentStage == stage {
            return
        }

        guard allowedStage == stage else {
            if allowedStage == nil {
                errorMessage = "Все этапы уже отмечены."
            } else {
                errorMessage = "Этапы нужно отмечать по порядку."
            }
            invalidateView()
            return
        }

        let previousStage = taskStages[taskID]
        taskStages[taskID] = stage
        invalidateView()

        guard let token = session.token else {
            taskStages[taskID] = previousStage
            errorMessage = "Сессия не найдена. Войдите снова."
            invalidateView()
            return
        }

        let announcementID = announcementCache[taskID]?.id
            ?? visibleTasks.first(where: { $0.id == taskID })?.announcementID
            ?? taskID

        do {
            let updated = try await announcementService.updateExecutionStage(
                token: token,
                announcementId: announcementID,
                stage: stage.apiValue
            )
            mergeAnnouncement(updated)
            if let syncedStage = taskStage(for: updated) {
                taskStages[taskID] = syncedStage
            } else {
                taskStages.removeValue(forKey: taskID)
            }

            if selectedAnnouncement?.id == updated.id {
                selectedAnnouncement = updated
            }

            if stage == .completed {
                acceptedAdditionalTaskIDs.removeAll { $0 == taskID }
                if taskID == routeContext?.entityID {
                    clearPerformerRouteState(message: "Задание завершено. Детали остались в чате.")
                } else {
                    await rebuildPerformerRouteTree()
                }
            } else {
                await rebuildPerformerRouteTree()
            }

            ensureSelections()
            updateFocusForCurrentSelection(fitMap: stage == .completed)
            errorMessage = nil
            invalidateView()
        } catch {
            taskStages[taskID] = previousStage
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            errorMessage = "Не удалось обновить этап выполнения: \(error.localizedDescription)"
            invalidateView()
        }
    }

    func openCurrentRouteInAppleMaps() {
        let items = performerNavigationMapItems
        guard items.count >= 2 else {
            errorMessage = "Маршрут пока нельзя открыть в Apple Maps."
            return
        }

        MKMapItem.openMaps(
            with: items,
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: (routeContext?.travelMode ?? .driving).appleMapsLaunchMode,
                MKLaunchOptionsShowsTrafficKey: NSNumber(value: true),
            ]
        )
    }

    private var performerHasContent: Bool {
        !performerTasks.isEmpty || performerMainCoordinates.count >= 2
    }

    private var customerHasContent: Bool {
        !customerTasks.isEmpty
    }

    private var performerMetrics: [Metric] {
        var metrics: [Metric] = []

        if performerDistanceMeters > 0 {
            metrics.append(Metric(id: "distance", title: "Маршрут", value: formatDistance(performerDistanceMeters)))
        }

        if performerDurationSeconds > 0 {
            metrics.append(Metric(id: "duration", title: "Время", value: formatDuration(performerDurationSeconds)))
        }

        metrics.append(
            Metric(
                id: "extra",
                title: "По пути",
                value: "\(acceptedAdditionalTaskIDs.count)/2 приняты"
            )
        )

        return metrics
    }

    private var customerMetrics: [Metric] {
        var metrics: [Metric] = [
            Metric(id: "tasks", title: "Задачи", value: "\(customerTasks.count)")
        ]

        if let selectedCustomerTaskID,
           let route = customerRouteCache[selectedCustomerTaskID] {
            metrics.append(Metric(id: "distance", title: "Маршрут", value: formatDistance(route.distanceMeters)))
            metrics.append(Metric(id: "duration", title: "Время", value: formatDuration(route.durationSeconds)))
        }

        return metrics
    }

    private var performerTasks: [TaskCard] {
        guard let baseRoute else { return [] }

        let primaryID = routeContext?.entityID ?? "primary-route"
        let primaryAnnouncement = announcementCache[primaryID]
        let primaryCoordinate = primaryAnnouncement?.destinationCoordinate
            ?? primaryAnnouncement?.mapCoordinate
            ?? routeContext?.end.coordinate
        let primaryStage = resolvedStage(for: primaryID, fallbackStatus: primaryAnnouncement?.status)

        var cards: [TaskCard] = [
            TaskCard(
                id: primaryID,
                title: primaryAnnouncement?.title ?? "Основное задание",
                subtitle: primaryAnnouncement?.shortStructuredSubtitle ?? baseRoute.endAddress,
                detailsText: descriptionText(for: primaryAnnouncement, fallbackAddress: baseRoute.endAddress),
                addressText: baseRoute.endAddress,
                priceText: primaryAnnouncement?.formattedBudgetText,
                badgeTitle: TaskKind.primary.badgeTitle,
                kind: .primary,
                coordinate: primaryCoordinate,
                stage: primaryStage,
                nextSelectableStage: nextSelectableStage(after: primaryStage),
                stageTitles: stageTitles(for: actionFamily(for: primaryAnnouncement, fallbackCategory: primaryAnnouncement?.category)),
                detourText: nil,
                previewSummary: nil,
                canUpdateStatus: true,
                canAcceptToRoute: false,
                canRemoveFromRoute: false,
                announcementID: primaryAnnouncement?.id ?? routeContext?.entityID
            )
        ]

        let acceptedTasks = orderedAcceptedTasks(from: baseRoute.tasksByRoute)
        cards.append(contentsOf: acceptedTasks.map(makeAcceptedTaskCard))

        let previewTasks = baseRoute.tasksByRoute
            .filter { !acceptedAdditionalTaskIDs.contains($0.id) }
            .map(makePreviewTaskCard)
        cards.append(contentsOf: previewTasks)

        return cards
    }

    private var customerTasks: [TaskCard] {
        trackedCustomerAnnouncements.map { announcement in
            let routeContext = customerRouteContexts[announcement.id]
            let stage = resolvedStage(for: announcement.id, fallbackStatus: announcement.status)
            return TaskCard(
                id: announcement.id,
                title: announcement.title,
                subtitle: announcement.shortStructuredSubtitle,
                detailsText: descriptionText(for: announcement, fallbackAddress: announcement.primaryDestinationAddress),
                addressText: routeContext?.endAddress ?? announcement.primaryDestinationAddress ?? announcement.primarySourceAddress,
                priceText: announcement.formattedBudgetText,
                badgeTitle: TaskKind.customerObserved.badgeTitle,
                kind: .customerObserved,
                coordinate: routeContext?.end.coordinate
                    ?? announcement.destinationCoordinate
                    ?? announcement.mapCoordinate
                    ?? announcement.sourceCoordinate,
                stage: stage,
                nextSelectableStage: nil,
                stageTitles: stageTitles(for: actionFamily(for: announcement, fallbackCategory: announcement.category)),
                detourText: nil,
                previewSummary: "Показываем только основной маршрут без чужих задач.",
                canUpdateStatus: false,
                canAcceptToRoute: false,
                canRemoveFromRoute: false,
                announcementID: announcement.id
            )
        }
    }

    private var performerMarkers: [RouteMapMarker] {
        var markers: [RouteMapMarker] = []

        if let start = routeContext?.start.coordinate {
            markers.append(
                RouteMapMarker(
                    id: "performer-start",
                    title: "Старт",
                    subtitle: routeContext?.startAddress,
                    coordinate: start,
                    kind: .start
                )
            )
        }

        if let currentUserCoordinate {
            markers.append(
                RouteMapMarker(
                    id: "performer-current-location",
                    title: "Вы сейчас",
                    subtitle: "Текущее положение устройства",
                    coordinate: currentUserCoordinate,
                    kind: .currentLocation
                )
            )
        }

        for task in performerTasks {
            guard let coordinate = task.coordinate else { continue }
            let markerKind: RouteMapMarkerKind
            switch task.kind {
            case .primary:
                markerKind = .primaryTask
            case .acceptedAdditional:
                markerKind = .acceptedTask
            case .previewBranch:
                markerKind = .previewTask
            case .customerObserved:
                markerKind = .customerTask
            }

            markers.append(
                RouteMapMarker(
                    id: task.id,
                    title: task.title,
                    subtitle: task.previewSummary ?? task.addressText,
                    coordinate: coordinate,
                    kind: markerKind
                )
            )
        }

        return markers
    }

    private var customerMarkers: [RouteMapMarker] {
        guard let selectedCustomerTaskID,
              let announcement = trackedCustomerAnnouncements.first(where: { $0.id == selectedCustomerTaskID }) else {
            return []
        }

        let routeContext = customerRouteContexts[selectedCustomerTaskID]
        var markers: [RouteMapMarker] = []
        if let source = routeContext?.start.coordinate ?? announcement.sourceCoordinate {
            markers.append(
                RouteMapMarker(
                    id: "customer-source-\(announcement.id)",
                    title: "Старт задачи",
                    subtitle: routeContext?.startAddress ?? announcement.primarySourceAddress,
                    coordinate: source,
                    kind: .start
                )
            )
        }

        if let destination = routeContext?.end.coordinate ?? announcement.destinationCoordinate ?? announcement.mapCoordinate {
            markers.append(
                RouteMapMarker(
                    id: announcement.id,
                    title: announcement.title,
                    subtitle: routeContext?.endAddress ?? announcement.primaryDestinationAddress ?? announcement.primarySourceAddress,
                    coordinate: destination,
                    kind: .customerTask
                )
            )
        }

        return markers
    }

    private var trackedCustomerAnnouncements: [AnnouncementDTO] {
        customerTrackedTaskIDs.compactMap { taskID in
            myAnnouncements.first(where: { $0.id == taskID })
        }
    }

    private var customerRouteCandidates: [AnnouncementDTO] {
        myAnnouncements
            .filter { !$0.taskState.isDeleted && $0.customerCanSeeExecutionRoute }
            .sorted { $0.createdAtDate > $1.createdAtDate }
    }

    private func fetchPublicAnnouncementsSafely() async -> [AnnouncementDTO] {
        do {
            return try await announcementService.publicAnnouncements()
        } catch {
            return []
        }
    }

    private func fetchMyAnnouncementsSafely(token: String) async -> [AnnouncementDTO] {
        do {
            return try await announcementService.myAnnouncements(token: token)
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return []
            }
            customerUnavailableMessage = "Не удалось загрузить задачи заказчика: \(error.localizedDescription)"
            return []
        }
    }

    private func loadPerformerData(token: String, autoRefresh: Bool) async {
        let previousPrimaryAnnouncement = routeContext.flatMap { announcementCache[$0.entityID] }

        do {
            let context = try await routeService.fetchMyCurrentRouteContext(token: token)
            let shouldRebuildBaseRoute =
                !autoRefresh
                || routeContext?.entityID != context.entityID
                || baseRoute == nil

            routeContext = context

            if shouldRebuildBaseRoute {
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

                let route = try await routeService.buildRoute(request: request, token: token)
                baseRoute = route
                performerMainCoordinates = route.polylineCoordinates
                performerDistanceMeters = route.distanceMeters
                performerDurationSeconds = route.durationSeconds
            }

            await refreshRouteAnnouncements(
                token: token,
                announcementIDs: performerAnnouncementIDsNeedingRefresh()
            )
            syncTaskStagesWithServerState()
            await rebuildPerformerRouteTree()
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }

            let routeWasCompleted = previousPrimaryAnnouncement?.taskState.executionStatus == .completed
            clearPerformerRouteState(
                message: routeWasCompleted
                    ? "Задание завершено. Детали остались в чате."
                    : (error.apiStatusCode == 404
                        ? "Основной маршрут пока недоступен. Он появится после принятия активного задания."
                        : "Не удалось загрузить маршрут исполнителя: \(error.localizedDescription)")
            )
        }
    }

    private func loadCustomerData(token: String) async {
        myAnnouncements = await fetchMyAnnouncementsSafely(token: token)
        for announcement in myAnnouncements {
            announcementCache[announcement.id] = mergeAnnouncement(
                preferred: announcement,
                fallback: announcementCache[announcement.id]
            )
        }
        syncTaskStagesWithServerState()
        await refreshCustomerTrackedTasks(token: token)
    }

    private func fetchAnnouncementSafely(token: String, announcementID: String) async -> AnnouncementDTO? {
        do {
            return try await announcementService.fetchAnnouncement(
                token: token,
                announcementId: announcementID
            )
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
            }
            return nil
        }
    }

    private func refreshRouteAnnouncements(token: String, announcementIDs: [String]) async {
        let uniqueIDs = Array(Set(announcementIDs))
        guard !uniqueIDs.isEmpty else { return }

        for announcementID in uniqueIDs {
            guard let announcement = await fetchAnnouncementSafely(
                token: token,
                announcementID: announcementID
            ) else {
                continue
            }
            mergeAnnouncement(announcement)
        }
    }

    private func performerAnnouncementIDsNeedingRefresh() -> [String] {
        var ids: [String] = []
        if let primaryID = routeContext?.entityID {
            ids.append(primaryID)
        }
        ids.append(contentsOf: acceptedAdditionalTaskIDs)
        return ids
    }

    private func clearAllState() {
        routeContext = nil
        baseRoute = nil
        performerMainCoordinates = []
        performerDistanceMeters = 0
        performerDurationSeconds = 0
        performerBranchPolylines = []
        publicAnnouncements = []
        myAnnouncements = []
        announcementCache = [:]
        customerRouteCache = [:]
        customerRouteContexts = [:]
        customerTrackedTaskIDs = []
        customerApproximateRouteTaskIDs = []
        acceptedAdditionalTaskIDs = []
        taskStages = [:]
        expandedTaskIDs = []
        selectedPerformerTaskID = nil
        selectedCustomerTaskID = nil
        focusedCoordinate = nil
    }

    private func clearPerformerRouteState(message: String) {
        routeContext = nil
        baseRoute = nil
        performerMainCoordinates = []
        performerDistanceMeters = 0
        performerDurationSeconds = 0
        performerBranchPolylines = []
        acceptedAdditionalTaskIDs = []
        expandedTaskIDs = []
        selectedPerformerTaskID = nil
        focusedCoordinate = nil
        performerRouteNote = nil
        performerUnavailableMessage = message
    }

    private func ensureSelections() {
        if selectedPerformerTaskID == nil || !performerTasks.contains(where: { $0.id == selectedPerformerTaskID }) {
            selectedPerformerTaskID = performerTasks.first?.id
        }

        if selectedCustomerTaskID == nil || !customerTasks.contains(where: { $0.id == selectedCustomerTaskID }) {
            selectedCustomerTaskID = customerTasks.first?.id
        }

        updateFocusForCurrentSelection(fitMap: !hasRenderableContent)
    }

    private func updateFocusForCurrentSelection(fitMap: Bool) {
        let selectedID = selectedTaskID
        let task = visibleTasks.first(where: { $0.id == selectedID }) ?? visibleTasks.first
        focusedCoordinate = task?.coordinate
        if fitMap || task == nil {
            shouldFitRoute = true
        }
        invalidateView()
    }

    private func mergedAnnouncementCache(
        publicAnnouncements: [AnnouncementDTO],
        myAnnouncements: [AnnouncementDTO]
    ) -> [String: AnnouncementDTO] {
        var cache: [String: AnnouncementDTO] = [:]

        for announcement in publicAnnouncements {
            cache[announcement.id] = mergeAnnouncement(
                preferred: announcement,
                fallback: cache[announcement.id]
            )
        }

        for announcement in myAnnouncements {
            cache[announcement.id] = mergeAnnouncement(
                preferred: announcement,
                fallback: cache[announcement.id]
            )
        }

        return cache
    }

    private func mergeAnnouncement(
        preferred: AnnouncementDTO,
        fallback: AnnouncementDTO?
    ) -> AnnouncementDTO {
        guard let fallback else { return preferred }

        var mergedData = fallback.data
        for (key, value) in preferred.data {
            mergedData[key] = value
        }

        if mergedData["media"] == nil, let fallbackMedia = fallback.data["media"] {
            mergedData["media"] = fallbackMedia
        }

        return AnnouncementDTO(
            id: preferred.id,
            user_id: preferred.user_id,
            category: preferred.category,
            title: preferred.title,
            status: preferred.status,
            data: mergedData,
            created_at: preferred.created_at,
            media: preferred.media ?? fallback.media
        )
    }

    private func rebuildPerformerRouteTree() async {
        performerBranchPolylines = []
        performerRouteNote = nil

        guard let routeContext, let baseRoute else { return }

        let acceptedTasks = orderedAcceptedTasks(from: baseRoute.tasksByRoute)
        if acceptedTasks.isEmpty {
            performerMainCoordinates = baseRoute.polylineCoordinates
            performerDistanceMeters = baseRoute.distanceMeters
            performerDurationSeconds = baseRoute.durationSeconds
        } else {
            isRebuildingRoute = true
            defer { isRebuildingRoute = false }

            do {
                let rebuilt = try await buildGeometryThroughWaypoints(
                    start: routeContext.start.coordinate,
                    waypoints: acceptedTasks.compactMap(\.coordinate),
                    end: routeContext.end.coordinate,
                    travelMode: routeContext.travelMode
                )

                performerMainCoordinates = rebuilt.polyline.compactMap { pair -> CLLocationCoordinate2D? in
                    guard pair.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
                }
                performerDistanceMeters = rebuilt.distanceMeters
                performerDurationSeconds = rebuilt.durationSeconds
            } catch {
                let approximate = approximateGeometry(
                    start: routeContext.start.coordinate,
                    waypoints: acceptedTasks.compactMap(\.coordinate),
                    end: routeContext.end.coordinate,
                    travelMode: routeContext.travelMode
                )
                performerMainCoordinates = approximate.polyline.compactMap { pair -> CLLocationCoordinate2D? in
                    guard pair.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
                }
                performerDistanceMeters = approximate.distanceMeters
                performerDurationSeconds = approximate.durationSeconds
                performerRouteNote = "Часть rebuild после принятия дополнительных задач показана приближённо: Apple Maps не вернул все сегменты."
            }
        }

        performerBranchPolylines = baseRoute.tasksByRoute
            .filter { !acceptedAdditionalTaskIDs.contains($0.id) }
            .compactMap { task in
                guard let taskCoordinate = task.coordinate,
                      let projection = closestProjection(on: performerMainCoordinates, to: taskCoordinate) else {
                    return nil
                }

                return RouteMapPolyline(
                    id: "preview-branch-\(task.id)",
                    coordinates: [projection.coordinate, taskCoordinate],
                    kind: .previewBranch
                )
            }

        shouldFitRoute = true
        invalidateView()
    }

    private func refreshCustomerTrackedTasks(token: String) async {
        let previousContexts = customerRouteContexts
        let previousRouteCache = customerRouteCache
        let previousApproximateRouteTaskIDs = customerApproximateRouteTaskIDs

        customerTrackedTaskIDs = []
        customerRouteContexts = [:]
        customerRouteCache = [:]
        customerApproximateRouteTaskIDs = []

        let candidates = Array(customerRouteCandidates.prefix(8))
        guard !candidates.isEmpty else {
            customerUnavailableMessage = "Здесь появятся только задания, которые уже принял исполнитель."
            return
        }

        var trackedTaskIDs: [String] = []
        var trackedContexts: [String: RouteContextDTO] = [:]
        var firstNon404Error: Error?

        for announcement in candidates {
            if let cachedContext = previousContexts[announcement.id] {
                trackedTaskIDs.append(announcement.id)
                trackedContexts[announcement.id] = cachedContext
                continue
            }

            do {
                let context = try await routeService.fetchRouteContext(
                    announcementID: announcement.id,
                    token: token
                )
                trackedTaskIDs.append(announcement.id)
                trackedContexts[announcement.id] = context
            } catch {
                if error.isUnauthorizedResponse {
                    await session.logout()
                    return
                }

                guard error.apiStatusCode != 404 else { continue }
                if firstNon404Error == nil {
                    firstNon404Error = error
                }
            }
        }

        customerTrackedTaskIDs = trackedTaskIDs
        customerRouteContexts = trackedContexts
        customerRouteCache = Dictionary(
            uniqueKeysWithValues: previousRouteCache.filter { trackedTaskIDs.contains($0.key) }
        )
        customerApproximateRouteTaskIDs = Set(
            previousApproximateRouteTaskIDs.filter { trackedTaskIDs.contains($0) }
        )

        if trackedTaskIDs.isEmpty {
            if let firstNon404Error {
                customerUnavailableMessage = "Не удалось загрузить задачи заказчика в исполнении: \(firstNon404Error.localizedDescription)"
            } else {
                customerUnavailableMessage = "Здесь показываются только задания, которые уже принял исполнитель."
            }
        } else if firstNon404Error != nil {
            customerUnavailableMessage = "Часть задач в работе сейчас недоступна."
        } else {
            customerUnavailableMessage = nil
        }
    }

    private func ensureCustomerRouteBuiltIfNeeded() async {
        guard let selectedCustomerTaskID,
              customerRouteCache[selectedCustomerTaskID] == nil,
              let announcement = trackedCustomerAnnouncements.first(where: { $0.id == selectedCustomerTaskID }) else {
            return
        }

        let context = customerRouteContexts[selectedCustomerTaskID]
        guard let start = context?.start.coordinate ?? announcement.sourceCoordinate,
              let end = context?.end.coordinate ?? announcement.destinationCoordinate ?? announcement.mapCoordinate else {
            return
        }

        do {
            let geometry = try await routeGeometryBuilder.buildRoute(
                start: start,
                end: end,
                travelMode: context?.travelMode ?? travelMode(for: announcement)
            )
            customerRouteCache[selectedCustomerTaskID] = geometry
        } catch {
            let approximate = approximateGeometry(
                start: start,
                waypoints: [],
                end: end,
                travelMode: context?.travelMode ?? travelMode(for: announcement)
            )
            customerRouteCache[selectedCustomerTaskID] = approximate
            customerApproximateRouteTaskIDs.insert(selectedCustomerTaskID)
        }

        shouldFitRoute = true
        invalidateView()
    }

    private func buildGeometryThroughWaypoints(
        start: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        end: CLLocationCoordinate2D,
        travelMode: RouteTravelMode
    ) async throws -> RouteGeometry {
        let points = [start] + waypoints + [end]
        guard points.count >= 2 else {
            return RouteGeometry(polyline: [], distanceMeters: 0, durationSeconds: 0)
        }

        var polyline: [[Double]] = []
        var distanceMeters = 0
        var durationSeconds = 0

        for index in 0..<(points.count - 1) {
            let segmentStart = points[index]
            let segmentEnd = points[index + 1]

            if CLLocation(latitude: segmentStart.latitude, longitude: segmentStart.longitude)
                .distance(from: CLLocation(latitude: segmentEnd.latitude, longitude: segmentEnd.longitude)) < 20 {
                if polyline.isEmpty {
                    polyline.append([segmentStart.latitude, segmentStart.longitude])
                }
                polyline.append([segmentEnd.latitude, segmentEnd.longitude])
                continue
            }

            let geometry = try await routeGeometryBuilder.buildRoute(
                start: segmentStart,
                end: segmentEnd,
                travelMode: travelMode
            )
            distanceMeters += geometry.distanceMeters
            durationSeconds += geometry.durationSeconds

            if polyline.isEmpty {
                polyline.append(contentsOf: geometry.polyline)
            } else {
                polyline.append(contentsOf: geometry.polyline.dropFirst())
            }
        }

        return RouteGeometry(
            polyline: polyline,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds
        )
    }

    private func approximateGeometry(
        start: CLLocationCoordinate2D,
        waypoints: [CLLocationCoordinate2D],
        end: CLLocationCoordinate2D,
        travelMode: RouteTravelMode
    ) -> RouteGeometry {
        let points = [start] + waypoints + [end]
        guard points.count >= 2 else {
            return RouteGeometry(polyline: [], distanceMeters: 0, durationSeconds: 0)
        }

        var polyline: [[Double]] = []
        var totalDistance: CLLocationDistance = 0

        for index in 0..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            if polyline.isEmpty {
                polyline.append([current.latitude, current.longitude])
            }
            polyline.append([next.latitude, next.longitude])

            let distance = CLLocation(latitude: current.latitude, longitude: current.longitude)
                .distance(from: CLLocation(latitude: next.latitude, longitude: next.longitude))
            totalDistance += distance
        }

        let speedMetersPerSecond = travelMode == .walking ? 1.35 : 8.5
        let duration = Int((totalDistance / speedMetersPerSecond).rounded())

        return RouteGeometry(
            polyline: polyline,
            distanceMeters: Int(totalDistance.rounded()),
            durationSeconds: max(1, duration)
        )
    }

    private func orderedAcceptedTasks(from tasks: [TaskByRouteDTO]) -> [TaskByRouteDTO] {
        let accepted = tasks.filter { acceptedAdditionalTaskIDs.contains($0.id) }
        let baseCoordinates = baseRoute?.polylineCoordinates ?? []

        return accepted.sorted { lhs, rhs in
            let leftProgress = lhs.coordinate.flatMap { closestProjection(on: baseCoordinates, to: $0)?.progress }
                ?? fallbackAcceptanceOrder(for: lhs.id)
            let rightProgress = rhs.coordinate.flatMap { closestProjection(on: baseCoordinates, to: $0)?.progress }
                ?? fallbackAcceptanceOrder(for: rhs.id)
            return leftProgress < rightProgress
        }
    }

    private func fallbackAcceptanceOrder(for taskID: String) -> Double {
        guard let index = acceptedAdditionalTaskIDs.firstIndex(of: taskID) else {
            return .greatestFiniteMagnitude
        }
        return Double(index)
    }

    private func makeAcceptedTaskCard(task: TaskByRouteDTO) -> TaskCard {
        let announcement = announcementCache[task.id]
        let stage = resolvedStage(for: task.id, fallbackStatus: task.status)
        return TaskCard(
            id: task.id,
            title: task.title,
            subtitle: announcement?.shortStructuredSubtitle ?? task.distanceLabel,
            detailsText: descriptionText(for: announcement, fallbackAddress: task.addressText),
            addressText: task.addressText,
            priceText: task.priceText ?? announcement?.formattedBudgetText,
            badgeTitle: TaskKind.acceptedAdditional.badgeTitle,
            kind: .acceptedAdditional,
            coordinate: task.coordinate ?? announcement?.mapCoordinate,
            stage: stage,
            nextSelectableStage: nextSelectableStage(after: stage),
            stageTitles: stageTitles(for: actionFamily(for: announcement, fallbackCategory: task.category)),
            detourText: approximateDetourText(for: task),
            previewSummary: "Ветка уже встроена в основной маршрут.",
            canUpdateStatus: true,
            canAcceptToRoute: false,
            canRemoveFromRoute: true,
            announcementID: announcement?.id ?? task.id
        )
    }

    private func makePreviewTaskCard(task: TaskByRouteDTO) -> TaskCard {
        let announcement = announcementCache[task.id]
        return TaskCard(
            id: task.id,
            title: task.title,
            subtitle: announcement?.shortStructuredSubtitle ?? task.distanceLabel,
            detailsText: descriptionText(for: announcement, fallbackAddress: task.addressText),
            addressText: task.addressText,
            priceText: task.priceText ?? announcement?.formattedBudgetText,
            badgeTitle: TaskKind.previewBranch.badgeTitle,
            kind: .previewBranch,
            coordinate: task.coordinate ?? announcement?.mapCoordinate,
            stage: nil,
            nextSelectableStage: nil,
            stageTitles: [],
            detourText: approximateDetourText(for: task),
            previewSummary: [task.distanceLabel, approximateDetourText(for: task)]
                .compactMap { $0 }
                .joined(separator: " • "),
            canUpdateStatus: false,
            canAcceptToRoute: acceptedAdditionalTaskIDs.count < 2,
            canRemoveFromRoute: false,
            announcementID: announcement?.id ?? task.id
        )
    }

    private func resolvedStage(for taskID: String, fallbackStatus: String?) -> TaskStage? {
        if let stage = taskStages[taskID] {
            return stage
        }

        if let announcement = announcementCache[taskID] {
            return taskStage(for: announcement)
        }

        return stageFromRemoteStatus(fallbackStatus)
    }

    private func taskStage(for announcement: AnnouncementDTO) -> TaskStage? {
        stageFromExecutionStatus(
            announcement.taskState.executionStatus,
            acceptedConfirmed: announcement.taskState.acceptedConfirmed
        )
    }

    private func stageFromExecutionStatus(
        _ status: TaskExecutionStatus,
        acceptedConfirmed: Bool
    ) -> TaskStage? {
        switch status {
        case .open, .awaitingAcceptance:
            return nil
        case .accepted:
            return acceptedConfirmed ? .accepted : nil
        case .enRoute:
            return .heading
        case .onSite:
            return .onSite
        case .inProgress:
            return .doing
        case .handoff:
            return .finishing
        case .completed:
            return .completed
        case .cancelled, .disputed:
            return nil
        }
    }

    private func stageFromRemoteStatus(_ status: String?) -> TaskStage? {
        let normalized = status?.lowercased() ?? ""
        if normalized.contains("complete") || normalized.contains("done") || normalized.contains("finish") {
            return .completed
        }
        if normalized.contains("almost") || normalized.contains("final") {
            return .finishing
        }
        if normalized.contains("doing") || normalized.contains("progress") {
            return .doing
        }
        if normalized.contains("arrive") || normalized.contains("onsite") {
            return .onSite
        }
        if normalized.contains("heading") || normalized.contains("route") {
            return .heading
        }
        return nil
    }

    private func mergeAnnouncement(_ announcement: AnnouncementDTO) {
        announcementCache[announcement.id] = announcement
        if let stage = taskStage(for: announcement) {
            taskStages[announcement.id] = stage
        } else {
            taskStages.removeValue(forKey: announcement.id)
        }

        if let index = myAnnouncements.firstIndex(where: { $0.id == announcement.id }) {
            myAnnouncements[index] = announcement
        }

        if let index = publicAnnouncements.firstIndex(where: { $0.id == announcement.id }) {
            if announcement.canAppearOnMap {
                publicAnnouncements[index] = announcement
            } else {
                publicAnnouncements.remove(at: index)
            }
        } else if announcement.canAppearOnMap {
            publicAnnouncements.append(announcement)
        }
    }

    private func syncTaskStagesWithServerState() {
        let activeAnnouncementIDs = Set(announcementCache.keys)
            .union(Set(baseRoute?.tasksByRoute.map(\.id) ?? []))
            .union(Set(routeContext.map { [$0.entityID] } ?? []))
        taskStages = taskStages.filter { activeAnnouncementIDs.contains($0.key) }

        for (announcementID, announcement) in announcementCache {
            if let stage = taskStage(for: announcement) {
                taskStages[announcementID] = stage
            } else {
                taskStages.removeValue(forKey: announcementID)
            }
        }
    }

    private func nextSelectableStage(after currentStage: TaskStage?) -> TaskStage? {
        guard let currentStage else { return .accepted }
        return TaskStage(rawValue: currentStage.rawValue + 1)
    }

    private func descriptionText(for announcement: AnnouncementDTO?, fallbackAddress: String?) -> String {
        guard let announcement else {
            if let fallbackAddress, !fallbackAddress.isEmpty {
                return fallbackAddress
            }
            return "Описание подтянется из карточки объявления, когда оно будет доступно локально."
        }

        var lines: [String] = []
        let structured = announcement.structuredData

        if let notes = structured.notes, !notes.isEmpty {
            lines.append(notes)
        } else if let taskBrief = structured.taskBrief, !taskBrief.isEmpty {
            lines.append(taskBrief)
        }

        if let source = announcement.primarySourceAddress {
            lines.append("Откуда: \(source)")
        }

        if let destination = announcement.primaryDestinationAddress {
            lines.append("Куда: \(destination)")
        }

        if let budget = announcement.formattedBudgetText {
            lines.append("Оплата: \(budget)")
        }

        if lines.isEmpty {
            lines.append(announcement.shortStructuredSubtitle)
        }

        return lines.joined(separator: "\n")
    }

    private func actionFamily(for announcement: AnnouncementDTO?, fallbackCategory: String?) -> ActionFamily {
        if let actionType = announcement?.structuredData.actionType {
            switch actionType {
            case .pickup: return .pickup
            case .buy: return .buy
            case .carry: return .carry
            case .ride: return .ride
            case .proHelp: return .proHelp
            case .other: return .other
            }
        }

        switch fallbackCategory?.lowercased() {
        case "delivery":
            return .pickup
        case "help":
            return .proHelp
        default:
            return .other
        }
    }

    private func stageTitles(for action: ActionFamily) -> [String] {
        TaskStage.allCases.map { title(for: $0, action: action) }
    }

    private func title(for stage: TaskStage, action: ActionFamily) -> String {
        switch (action, stage) {
        case (_, .accepted):
            return "Принял"

        case (.pickup, .heading):
            return "Еду забирать"
        case (.buy, .heading):
            return "Еду за покупкой"
        case (.carry, .heading):
            return "Еду на точку"
        case (.ride, .heading):
            return "Еду к пассажиру"
        case (.proHelp, .heading):
            return "Еду на место"
        case (.other, .heading):
            return "Направляюсь"

        case (.pickup, .onSite):
            return "На месте"
        case (.buy, .onSite):
            return "В магазине"
        case (.carry, .onSite):
            return "На месте"
        case (.ride, .onSite):
            return "У пассажира"
        case (.proHelp, .onSite):
            return "На месте"
        case (.other, .onSite):
            return "На месте"

        case (.pickup, .doing):
            return "Забираю"
        case (.buy, .doing):
            return "Покупаю"
        case (.carry, .doing):
            return "Переношу"
        case (.ride, .doing):
            return "Везу"
        case (.proHelp, .doing):
            return "Выполняю"
        case (.other, .doing):
            return "Выполняю"

        case (.pickup, .finishing):
            return "Везу получателю"
        case (.buy, .finishing):
            return "Везу заказ"
        case (.carry, .finishing):
            return "Почти готово"
        case (.ride, .finishing):
            return "Подъезжаю"
        case (.proHelp, .finishing):
            return "Проверяю"
        case (.other, .finishing):
            return "Почти готово"

        case (.pickup, .completed):
            return "Передал"
        case (.buy, .completed):
            return "Доставил"
        case (.carry, .completed):
            return "Готово"
        case (.ride, .completed):
            return "Высадил"
        case (.proHelp, .completed):
            return "Завершил"
        case (.other, .completed):
            return "Завершил"
        }
    }

    private func approximateDetourText(for task: TaskByRouteDTO) -> String? {
        guard let routeContext else { return nil }
        let distanceFromRoute = task.distanceToRouteMeters ?? 180
        let approximateDistance = Int((distanceFromRoute * 2.3).rounded())
        let speedMetersPerMinute = routeContext.travelMode == .walking ? 75.0 : 520.0
        let minutes = max(1, Int((Double(approximateDistance) / speedMetersPerMinute).rounded()))
        return "Отклонение ~\(formatDistance(approximateDistance)) • \(minutes) мин"
    }

    private func travelMode(for announcement: AnnouncementDTO) -> RouteTravelMode {
        let structured = announcement.structuredData
        if structured.actionType == .ride || structured.requiresVehicle || announcement.category == "delivery" {
            return .driving
        }
        return .walking
    }

    private var performerNavigationMapItems: [MKMapItem] {
        guard let endCoordinate = routeContext?.end.coordinate else { return [] }

        var items: [MKMapItem] = []

        if currentUserCoordinate != nil {
            let currentItem = MKMapItem.forCurrentLocation()
            currentItem.name = "Вы"
            items.append(currentItem)
        } else if let startCoordinate = routeContext?.start.coordinate {
            items.append(mapItem(named: "Старт", coordinate: startCoordinate))
        }

        if let baseRoute {
            for task in orderedAcceptedTasks(from: baseRoute.tasksByRoute) {
                guard let coordinate = task.coordinate else { continue }
                items.append(mapItem(named: task.title, coordinate: coordinate))
            }
        }

        let finalTitle = announcementCache[routeContext?.entityID ?? ""]?.title
            ?? baseRoute?.endAddress
            ?? "Пункт назначения"
        items.append(mapItem(named: finalTitle, coordinate: endCoordinate))
        return items
    }

    private func mapItem(named name: String, coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        return item
    }

    private func formatDistance(_ meters: Int) -> String {
        if meters >= 1000 {
            return String(format: "%.1f км", Double(meters) / 1000)
        }
        return "\(meters) м"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = max(1, Int((Double(seconds) / 60).rounded()))
        if minutes >= 60 {
            let hours = minutes / 60
            let rest = minutes % 60
            if rest == 0 {
                return "\(hours) ч"
            }
            return "\(hours) ч \(rest) мин"
        }
        return "\(minutes) мин"
    }

    private func closestProjection(
        on coordinates: [CLLocationCoordinate2D],
        to coordinate: CLLocationCoordinate2D
    ) -> RouteProjection? {
        guard coordinates.count >= 2 else { return nil }

        let target = MKMapPoint(coordinate)
        let totalLength = polylineLength(for: coordinates)
        var traversed: CLLocationDistance = 0
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        var bestProjection: RouteProjection?

        for index in 0..<(coordinates.count - 1) {
            let startCoordinate = coordinates[index]
            let endCoordinate = coordinates[index + 1]
            let start = MKMapPoint(startCoordinate)
            let end = MKMapPoint(endCoordinate)
            let segmentLength = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
                .distance(from: CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude))

            let projection = project(point: target, ontoSegmentFrom: start, to: end)
            let projectionDistance = projection.mapPoint.distance(to: target)
            if projectionDistance < bestDistance {
                bestDistance = projectionDistance
                let progress = totalLength > 0
                    ? (traversed + segmentLength * projection.fraction) / totalLength
                    : 0
                bestProjection = RouteProjection(
                    coordinate: projection.mapPoint.coordinate,
                    distanceMeters: projectionDistance,
                    progress: progress
                )
            }

            traversed += segmentLength
        }

        return bestProjection
    }

    private func polylineLength(for coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard coordinates.count >= 2 else { return 0 }
        return zip(coordinates, coordinates.dropFirst()).reduce(0) { partial, pair in
            partial + CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
        }
    }

    private func project(
        point: MKMapPoint,
        ontoSegmentFrom start: MKMapPoint,
        to end: MKMapPoint
    ) -> SegmentProjection {
        let dx = end.x - start.x
        let dy = end.y - start.y

        guard dx != 0 || dy != 0 else {
            return SegmentProjection(mapPoint: start, fraction: 0)
        }

        let rawFraction = ((point.x - start.x) * dx + (point.y - start.y) * dy) / (dx * dx + dy * dy)
        let fraction = max(0, min(1, rawFraction))
        let projectedPoint = MKMapPoint(
            x: start.x + dx * fraction,
            y: start.y + dy * fraction
        )
        return SegmentProjection(mapPoint: projectedPoint, fraction: fraction)
    }

    private func invalidateView() {
        renderTrigger &+= 1
    }
}

private extension RouteViewModel.TaskStage {
    var apiValue: String {
        switch self {
        case .accepted:
            return "accepted"
        case .heading:
            return "en_route"
        case .onSite:
            return "on_site"
        case .doing:
            return "in_progress"
        case .finishing:
            return "handoff"
        case .completed:
            return "completed"
        }
    }
}

private extension RouteTravelMode {
    var appleMapsLaunchMode: String {
        switch self {
        case .driving:
            return MKLaunchOptionsDirectionsModeDriving
        case .walking:
            return MKLaunchOptionsDirectionsModeWalking
        }
    }
}

private extension RouteViewModel {
    enum ActionFamily {
        case pickup
        case buy
        case carry
        case ride
        case proHelp
        case other
    }

    struct RouteProjection {
        let coordinate: CLLocationCoordinate2D
        let distanceMeters: CLLocationDistance
        let progress: Double
    }

    struct SegmentProjection {
        let mapPoint: MKMapPoint
        let fraction: Double
    }
}

private extension MKMapPoint {
    func distance(to point: MKMapPoint) -> CLLocationDistance {
        let first = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let second = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
        return first.distance(from: second)
    }
}
