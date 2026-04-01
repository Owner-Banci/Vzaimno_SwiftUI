import CoreLocation
import SwiftUI

#if canImport(YandexMapsMobile)
import YandexMapsMobile
#endif

struct MapScreen: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionStore
    @StateObject private var vm: MapViewModel
    private let mapMode: MapDisplayMode

    init(
        vm: MapViewModel,
        mapMode: MapDisplayMode = MapDisplayConfig.defaultMode()
    ) {
        _vm = StateObject(wrappedValue: vm)
        self.mapMode = mapMode
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 12) {
                topOverlay

                if vm.isListMode {
                    listSurface
                } else {
                    Spacer(minLength: 0)
                }
            }

            if !vm.isListMode {
                mapActionButtonsOverlay
            }

            floatingFiltersButton
        }
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .task {
            await vm.reloadPins()
            vm.startAutoRefresh()
        }
        .onDisappear {
            vm.stopAutoRefresh()
        }
        .sheet(item: $vm.selectedAnnouncement, onDismiss: {
            vm.clearSelection()
        }) { announcement in
            AnnouncementSheetView(
                announcement: announcement,
                service: container.announcementService,
                session: session
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.isFiltersPresented) {
            MapFiltersSheet(vm: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if vm.isListMode {
            Theme.ColorToken.milk
                .ignoresSafeArea()
        } else {
            mapLayer
        }
    }

    @ViewBuilder
    private var mapLayer: some View {
        switch mapMode {
        case .apple:
            AppleTaskMapView(
                visibleCenterCoordinate: $vm.visibleCenterCoordinate,
                tasks: vm.filteredTasks,
                selectedAnnouncementID: vm.selectedAnnouncementID,
                routeCoordinates: vm.routeState?.coordinates ?? [],
                shouldFitRoute: vm.shouldFitRoute,
                cameraCommand: vm.cameraCommand,
                onRouteFitted: vm.consumeRouteFitRequest,
                onCameraCommandHandled: vm.consumeCameraCommand(_:),
                onPinTap: { pinID in
                    Task { @MainActor in
                        await vm.selectAnnouncement(pinID: pinID)
                    }
                }
            )
            .ignoresSafeArea()

        case .yandex:
            #if canImport(YandexMapsMobile)
            YandexMapView(
                centerPoint: Binding(
                    get: {
                        guard let center = vm.visibleCenterCoordinate else { return nil }
                        return YMKPoint(latitude: center.latitude, longitude: center.longitude)
                    },
                    set: { newPoint in
                        guard let newPoint else { return }
                        vm.visibleCenterCoordinate = CLLocationCoordinate2D(
                            latitude: newPoint.latitude,
                            longitude: newPoint.longitude
                        )
                    }
                ),
                pins: vm.mappedPins,
                selectedPinID: vm.selectedAnnouncementID,
                routePolyline: nil,
                shouldFitRoute: false,
                onRouteFitted: {},
                onPinTap: { pinID in
                    Task { @MainActor in
                        await vm.selectAnnouncement(pinID: pinID)
                    }
                }
            )
            .ignoresSafeArea()
            #else
            mapUnavailableState(title: "Yandex Maps недоступен в этой сборке")
            #endif

        case .placeholder:
            mapUnavailableState(title: "Карта временно недоступна")
        }
    }

    private func mapUnavailableState(title: String) -> some View {
        Rectangle()
            .fill(Theme.ColorToken.milk)
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "map")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                }
            )
            .ignoresSafeArea()
    }

    private var topOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.ColorToken.textSecondary)

                    TextField("Поиск по названию и параметрам", text: $vm.searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)
                        .onSubmit {
                            vm.performSearch()
                        }

                    if !vm.searchText.isEmpty {
                        Button {
                            vm.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.ColorToken.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(liquidGlassShape(cornerRadius: 18))
                .softCardShadow()

                Button {
                    vm.toggleContentMode()
                } label: {
                    Image(systemName: vm.surfaceToggleSystemImage)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(liquidGlassShape(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .softCardShadow()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.quickFilters) { filter in
                        FilterChip(
                            title: filter.title,
                            isSelected: vm.filters.selectedActions.contains(filter)
                        ) {
                            vm.toggleQuickFilter(filter)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }

            if vm.isListMode {
                listSummaryStrip
            }

            if let message = vm.errorMessage ?? vm.routeErrorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var listSummaryStrip: some View {
        HStack(spacing: 10) {
            Text(vm.displayedCountText)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ColorToken.textPrimary)

            if let routeText = vm.routeMatchedCountText {
                Text(routeText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ColorToken.turquoise)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.ColorToken.turquoise.opacity(0.08), lineWidth: 1)
        )
    }

    private var listSurface: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                if vm.filteredTasks.isEmpty {
                    emptyState
                } else {
                    ForEach(vm.filteredTasks) { task in
                        MapAnnouncementListCard(task: task) {
                            vm.showMapMode()
                            vm.highlightAnnouncement(task)
                        } onOpen: {
                            vm.selectAnnouncementFromList(task)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 150)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
            Text("Ничего не найдено")
                .font(.system(size: 17, weight: .bold))
            Text("Смените фильтры, маршрут или поисковый запрос.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.ColorToken.milk.opacity(0.65))
        )
    }

    private var mapActionButtonsOverlay: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()
                VStack(spacing: 10) {
                    mapButton(systemImage: "plus") { vm.zoomIn() }
                    mapButton(systemImage: "minus") { vm.zoomOut() }
                    mapButton(systemImage: "location") { vm.centerOnUser() }
                    mapButton(systemImage: "hand.tap") { }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 188)
        }
    }

    private var floatingFiltersButton: some View {
        VStack {
            Spacer()

            Button {
                vm.presentFilters()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.textPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.filterButtonTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.ColorToken.textPrimary)
                        Text(vm.filterButtonSubtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.turquoise)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: 320)
                .background(liquidGlassShape(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .softCardShadow()
            .padding(.horizontal, 16)
            .padding(.bottom, 102)
        }
    }

    private func mapButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ColorToken.textPrimary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
        }
        .buttonStyle(.plain)
        .softCardShadow()
    }

    private func liquidGlassShape(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}

private struct MapAnnouncementListCard: View {
    let task: MapTaskPresentation
    let onShowOnMap: () -> Void
    let onOpen: () -> Void

    var body: some View {
        Group {
            if task.announcement.hasAttachedMedia {
                mediaRow
            } else {
                textOnlyRow
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    task.isOnRoute ? Theme.ColorToken.turquoise.opacity(0.18) : Theme.ColorToken.turquoise.opacity(0.08),
                    lineWidth: 1
                )
        )
        .softCardShadow()
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onOpen)
    }

    private var mediaRow: some View {
        HStack(alignment: .top, spacing: 12) {
            AnnouncementImageView(
                url: task.previewURL,
                width: 92,
                height: 92,
                cornerRadius: 14
            )

            VStack(alignment: .leading, spacing: 8) {
                header(showMediaMeta: true)
                routeAndBudget
                tagsRow
                actionRow
            }
        }
    }

    private var textOnlyRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(showMediaMeta: false)
            HStack(spacing: 8) {
                infoPill(title: task.actionTitle, systemImage: "shippingbox")
                infoPill(title: "Без фото", systemImage: "photo.slash")
                if task.isOnRoute {
                    infoPill(title: "По пути", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }
                Spacer(minLength: 0)
            }
            routeAndBudget
            tagsRow
            actionRow
        }
    }

    private func header(showMediaMeta: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if !task.subtitle.isEmpty {
                    Text(task.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if showMediaMeta {
                    Text(task.actionTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if task.isOnRoute {
                Text("По пути")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.ColorToken.turquoise))
            }
        }
    }

    private var routeAndBudget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(task.budgetText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ColorToken.textPrimary)

                Text("•")
                    .foregroundStyle(Theme.ColorToken.textSecondary)

                Text(task.distanceLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
            }

            if let eta = task.etaLabel {
                Text(eta)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var tagsRow: some View {
        if !task.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(task.tags, id: \.self) { badge in
                        CreateAdInfoTag(title: badge)
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        Button(action: onShowOnMap) {
            Label("Показать на карте", systemImage: "mappin.and.ellipse")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ColorToken.turquoise)
        }
        .buttonStyle(.plain)
    }

    private func infoPill(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.ColorToken.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Theme.ColorToken.milk)
        )
    }
}

private struct MapFiltersSheet: View {
    @ObservedObject var vm: MapViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    private var selectedActions: Set<MapQuickActionFilter> {
        vm.filters.selectedActions
    }

    private var focusedOnBuy: Bool {
        selectedActions == [.buy]
    }

    private var focusedOnRide: Bool {
        selectedActions == [.ride]
    }

    private var focusedOnProHelp: Bool {
        selectedActions == [.proHelp]
    }

    private var showsGenericItems: Bool {
        if focusedOnRide || focusedOnProHelp { return false }
        return selectedActions.isEmpty
            || selectedActions.contains(.pickup)
            || selectedActions.contains(.carry)
    }

    private var showsPurchaseItems: Bool {
        selectedActions.isEmpty || selectedActions.contains(.buy)
    }

    private var showsHelpTypes: Bool {
        selectedActions.isEmpty || selectedActions.contains(.proHelp)
    }

    private var showsDestinationKinds: Bool {
        !focusedOnProHelp
    }

    private var showsWeightAndSize: Bool {
        !focusedOnRide && !focusedOnProHelp
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    routeSection
                    actionsSection

                    if showsGenericItems {
                        genericItemsSection
                    }

                    if showsPurchaseItems {
                        purchaseItemsSection
                    }

                    if showsHelpTypes {
                        helpTypesSection
                    }

                    sourceSection

                    if showsDestinationKinds {
                        destinationSection
                    }

                    urgencySection
                    conditionsSection

                    if showsWeightAndSize {
                        sizeSection
                    }

                    budgetSection
                    photoSection
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.ColorToken.milk.ignoresSafeArea())
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Сбросить") {
                        vm.filters.resetAll()
                        vm.routeStartAddress = ""
                        vm.routeEndAddress = ""
                        vm.clearRoute()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        vm.dismissFilters()
                        dismiss()
                    }
                }
            }
        }
    }

    private var routeSection: some View {
        CreateAdSectionCard(
            title: "Маршрут пользователя",
            subtitle: "Задайте путь и при желании оставьте только задачи по пути.",
            accent: Theme.ColorToken.turquoise
        ) {
            VStack(spacing: 12) {
                filterTextField(
                    title: "Откуда",
                    placeholder: "Введите стартовый адрес",
                    text: $vm.routeStartAddress
                )

                filterTextField(
                    title: "Куда",
                    placeholder: "Введите адрес прибытия",
                    text: $vm.routeEndAddress
                )

                if let routeMeta = vm.routeMetaText {
                    HStack(spacing: 8) {
                        CreateAdInfoTag(title: routeMeta, systemImage: "map")
                        if let matched = vm.routeMatchedCountText {
                            Text(matched)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.ColorToken.textSecondary)
                        }
                    }
                }

                CreateAdToggleTile(
                    title: "Показывать только задачи по пути",
                    subtitle: "Оставить в списке только объявления рядом с маршрутом.",
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                    isOn: binding(for: \.onlyOnRoute)
                )

                HStack(spacing: 10) {
                    Button {
                        Task { await vm.buildRoute() }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isBuildingRoute {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.triangle.branch")
                            }
                            Text(vm.isBuildingRoute ? "Строим..." : "Построить маршрут")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.ColorToken.turquoise)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isBuildingRoute)

                    if vm.hasRoute {
                        Button("Сбросить") {
                            vm.clearRoute()
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.8))
                        )
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        CreateAdSectionCard(
            title: "Главные категории",
            subtitle: "Быстро сузьте список по типу задачи.",
            accent: Theme.ColorToken.turquoise
        ) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(MapQuickActionFilter.allCases) { action in
                    CreateAdChoiceChip(
                        title: action.title,
                        isSelected: vm.filters.selectedActions.contains(action),
                        compact: true
                    ) {
                        vm.filters.toggleAction(action)
                    }
                }
            }
        }
    }

    private var genericItemsSection: some View {
        CreateAdSectionCard(
            title: "Что именно",
            subtitle: "Обычные поручения: доставка, перенос, забор.",
            accent: Theme.ColorToken.turquoise
        ) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CreateAdDraft.ItemType.allCases) { item in
                    CreateAdChoiceChip(
                        title: item.title,
                        systemImage: item.systemImage,
                        isSelected: vm.filters.itemTypes.contains(item.rawValue),
                        compact: true
                    ) {
                        toggleStringValue(item.rawValue, in: \.itemTypes)
                    }
                }
            }
        }
    }

    private var purchaseItemsSection: some View {
        CreateAdSectionCard(
            title: "Что купить",
            subtitle: "Покупки фильтруются отдельно от обычных вещей.",
            accent: Theme.ColorToken.turquoise
        ) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CreateAdDraft.PurchaseType.allCases) { item in
                    CreateAdChoiceChip(
                        title: item.title,
                        systemImage: item.systemImage,
                        isSelected: vm.filters.itemTypes.contains(item.rawValue),
                        compact: true
                    ) {
                        toggleStringValue(item.rawValue, in: \.itemTypes)
                    }
                }
            }
        }
    }

    private var helpTypesSection: some View {
        CreateAdSectionCard(
            title: "Тип помощи",
            subtitle: "Для задач формата «Помощь от профи».",
            accent: Theme.ColorToken.turquoise
        ) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CreateAdDraft.HelpType.allCases) { item in
                    CreateAdChoiceChip(
                        title: item.title,
                        systemImage: item.systemImage,
                        isSelected: vm.filters.helpTypes.contains(item.rawValue),
                        compact: true
                    ) {
                        toggleStringValue(item.rawValue, in: \.helpTypes)
                    }
                }
            }
        }
    }

    private var sourceSection: some View {
        CreateAdSectionCard(
            title: "Откуда",
            subtitle: "Источник задачи или место старта.",
            accent: Theme.ColorToken.turquoise
        ) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CreateAdDraft.SourceKind.allCases) { kind in
                    CreateAdChoiceChip(
                        title: kind.title,
                        systemImage: kind.systemImage,
                        isSelected: vm.filters.sourceKinds.contains(kind.toStructuredSourceKind),
                        compact: true
                    ) {
                        toggleEnumValue(kind.toStructuredSourceKind, in: \.sourceKinds)
                    }
                }
            }
        }
    }

    private var destinationSection: some View {
        CreateAdSectionCard(
            title: "Куда",
            subtitle: "Финальная точка задачи или доставки.",
            accent: Theme.ColorToken.turquoise
        ) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CreateAdDraft.DestinationKind.allCases) { kind in
                    CreateAdChoiceChip(
                        title: kind.title,
                        systemImage: kind.systemImage,
                        isSelected: vm.filters.destinationKinds.contains(kind.toStructuredDestinationKind),
                        compact: true
                    ) {
                        toggleEnumValue(kind.toStructuredDestinationKind, in: \.destinationKinds)
                    }
                }
            }
        }
    }

    private var urgencySection: some View {
        CreateAdSectionCard(
            title: "Когда",
            subtitle: "Можно выбрать один или несколько сценариев срочности.",
            accent: Theme.ColorToken.turquoise
        ) {
            VStack(spacing: 12) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CreateAdDraft.Urgency.allCases) { urgency in
                        CreateAdChoiceChip(
                            title: urgency.title,
                            systemImage: urgency.systemImage,
                            isSelected: vm.filters.urgencies.contains(urgency.toStructuredUrgency),
                            compact: true
                        ) {
                            toggleEnumValue(urgency.toStructuredUrgency, in: \.urgencies)
                        }
                    }
                }

                CreateAdToggleTile(
                    title: "Только срочные",
                    subtitle: "Оставить только «Сейчас» и «Сегодня».",
                    systemImage: "bolt.fill",
                    isOn: binding(for: \.onlyUrgent)
                )
            }
        }
    }

    private var conditionsSection: some View {
        CreateAdSectionCard(
            title: "Условия выполнения",
            subtitle: "Execution modifiers из structured-задач.",
            accent: Theme.ColorToken.turquoise
        ) {
            LazyVGrid(columns: columns, spacing: 10) {
                CreateAdToggleTile(
                    title: "Нужна машина",
                    systemImage: "car",
                    isOn: optionalTrueBinding(for: \.requiresVehicle)
                )
                CreateAdToggleTile(
                    title: "Нужен багажник",
                    systemImage: "car.rear.and.tire.marks",
                    isOn: optionalTrueBinding(for: \.needsTrunk)
                )
                CreateAdToggleTile(
                    title: "Аккуратно",
                    systemImage: "hand.raised.square.on.square",
                    isOn: optionalTrueBinding(for: \.requiresCarefulHandling)
                )
                CreateAdToggleTile(
                    title: "Есть лифт",
                    systemImage: "arrow.up.forward.square",
                    isOn: optionalTrueBinding(for: \.hasElevator)
                )
                CreateAdToggleTile(
                    title: "Нужен грузчик",
                    systemImage: "person.2",
                    isOn: optionalTrueBinding(for: \.needsLoader)
                )
                CreateAdToggleTile(
                    title: "Подождать на месте",
                    systemImage: "hourglass",
                    isOn: optionalTrueBinding(for: \.waitOnSite)
                )
                CreateAdToggleTile(
                    title: "Созвониться заранее",
                    systemImage: "phone",
                    isOn: optionalTrueBinding(for: \.callBeforeArrival)
                )
                CreateAdToggleTile(
                    title: "Нужен код",
                    systemImage: "number.square",
                    isOn: optionalTrueBinding(for: \.requiresConfirmationCode)
                )
                CreateAdToggleTile(
                    title: "Бесконтактно",
                    systemImage: "hand.wave",
                    isOn: optionalTrueBinding(for: \.contactless)
                )
                CreateAdToggleTile(
                    title: "Нужен чек",
                    systemImage: "receipt",
                    isOn: optionalTrueBinding(for: \.requiresReceipt)
                )
                CreateAdToggleTile(
                    title: "Нужен фотоотчёт",
                    systemImage: "camera",
                    isOn: optionalTrueBinding(for: \.photoReportRequired)
                )
            }
        }
    }

    private var sizeSection: some View {
        VStack(spacing: 16) {
            CreateAdSectionCard(
                title: "Вес",
                subtitle: "Быстрые диапазоны веса.",
                accent: Theme.ColorToken.turquoise
            ) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CreateAdDraft.WeightCategory.allCases) { weight in
                        CreateAdChoiceChip(
                            title: weight.title,
                            isSelected: vm.filters.weightCategories.contains(weight.toStructuredWeightCategory),
                            compact: true
                        ) {
                            toggleEnumValue(weight.toStructuredWeightCategory, in: \.weightCategories)
                        }
                    }
                }
            }

            CreateAdSectionCard(
                title: "Размер",
                subtitle: "Пресеты габаритов из create-flow.",
                accent: Theme.ColorToken.turquoise
            ) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CreateAdDraft.SizeCategory.allCases) { size in
                        CreateAdChoiceChip(
                            title: size.title,
                            isSelected: vm.filters.sizeCategories.contains(size.toStructuredSizeCategory),
                            compact: true
                        ) {
                            toggleEnumValue(size.toStructuredSizeCategory, in: \.sizeCategories)
                        }
                    }
                }
            }
        }
    }

    private var budgetSection: some View {
        CreateAdSectionCard(
            title: "Бюджет",
            subtitle: "Диапазон стоимости для списка и карты.",
            accent: Theme.ColorToken.turquoise
        ) {
            HStack(spacing: 10) {
                filterTextField(
                    title: "От",
                    placeholder: "0",
                    text: budgetBinding(for: \.budgetMin),
                    keyboard: .numberPad
                )
                filterTextField(
                    title: "До",
                    placeholder: "5000",
                    text: budgetBinding(for: \.budgetMax),
                    keyboard: .numberPad
                )
            }
        }
    }

    private var photoSection: some View {
        CreateAdSectionCard(
            title: "Фото",
            subtitle: "Можно оставить только объявления с фото или без него.",
            accent: Theme.ColorToken.turquoise
        ) {
            HStack(spacing: 10) {
                photoChip(title: "Любые", value: .any)
                photoChip(title: "С фото", value: .withPhoto)
                photoChip(title: "Без фото", value: .withoutPhoto)
            }
        }
    }

    private func photoChip(title: String, value: MapTaskPhotoFilter) -> some View {
        CreateAdChoiceChip(
            title: title,
            isSelected: vm.filters.photoFilter == value,
            compact: true
        ) {
            vm.filters.photoFilter = vm.filters.photoFilter == value ? .any : value
        }
    }

    private func filterTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)

            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.ColorToken.turquoise.opacity(0.10), lineWidth: 1)
                )
        }
    }

    private func binding(for keyPath: WritableKeyPath<AnnouncementSearchFilters, Bool>) -> Binding<Bool> {
        Binding(
            get: { vm.filters[keyPath: keyPath] },
            set: { vm.filters[keyPath: keyPath] = $0 }
        )
    }

    private func optionalTrueBinding(for keyPath: WritableKeyPath<AnnouncementSearchFilters, Bool?>) -> Binding<Bool> {
        Binding(
            get: { vm.filters[keyPath: keyPath] == true },
            set: { vm.filters[keyPath: keyPath] = $0 ? true : nil }
        )
    }

    private func budgetBinding(for keyPath: WritableKeyPath<AnnouncementSearchFilters, Int?>) -> Binding<String> {
        Binding(
            get: {
                guard let value = vm.filters[keyPath: keyPath] else { return "" }
                return String(value)
            },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                vm.filters[keyPath: keyPath] = digits.isEmpty ? nil : Int(digits)
            }
        )
    }

    private func toggleStringValue(
        _ rawValue: String,
        in keyPath: WritableKeyPath<AnnouncementSearchFilters, Set<String>>
    ) {
        if vm.filters[keyPath: keyPath].contains(rawValue) {
            vm.filters[keyPath: keyPath].remove(rawValue)
        } else {
            vm.filters[keyPath: keyPath].insert(rawValue)
        }
    }

    private func toggleEnumValue<T: Hashable>(
        _ value: T,
        in keyPath: WritableKeyPath<AnnouncementSearchFilters, Set<T>>
    ) {
        if vm.filters[keyPath: keyPath].contains(value) {
            vm.filters[keyPath: keyPath].remove(value)
        } else {
            vm.filters[keyPath: keyPath].insert(value)
        }
    }
}

private extension CreateAdDraft.Urgency {
    var toStructuredUrgency: AnnouncementStructuredData.Urgency {
        switch self {
        case .now: return .now
        case .today: return .today
        case .scheduled: return .scheduled
        case .flexible: return .flexible
        }
    }
}

private extension CreateAdDraft.WeightCategory {
    var toStructuredWeightCategory: AnnouncementStructuredData.WeightCategory {
        switch self {
        case .upTo1kg: return .upTo1kg
        case .upTo3kg: return .upTo3kg
        case .upTo7kg: return .upTo7kg
        case .upTo15kg: return .upTo15kg
        case .over15kg: return .over15kg
        }
    }
}

private extension CreateAdDraft.SizeCategory {
    var toStructuredSizeCategory: AnnouncementStructuredData.SizeCategory {
        switch self {
        case .pocket: return .pocket
        case .hand: return .hand
        case .backpack: return .backpack
        case .trunk: return .trunk
        case .bulky: return .bulky
        }
    }
}

private extension CreateAdDraft.SourceKind {
    var toStructuredSourceKind: AnnouncementStructuredData.SourceKind {
        switch self {
        case .person: return .person
        case .pickupPoint: return .pickupPoint
        case .venue: return .venue
        case .address: return .address
        case .office: return .office
        case .other: return .other
        }
    }
}

private extension CreateAdDraft.DestinationKind {
    var toStructuredDestinationKind: AnnouncementStructuredData.DestinationKind {
        switch self {
        case .person: return .person
        case .address: return .address
        case .office: return .office
        case .entrance: return .entrance
        case .metro: return .metro
        case .other: return .other
        }
    }
}
