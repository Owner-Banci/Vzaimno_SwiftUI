import SwiftUI

struct RouteScreen: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionStore
    @StateObject var vm: RouteViewModel

    init(vm: RouteViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        Group {
            if vm.isLoading, !vm.hasRenderableContent, vm.visibleTasks.isEmpty {
                loadingView
            } else {
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await vm.load()
            vm.startAutoRefresh()
        }
        .onDisappear {
            vm.stopAutoRefresh()
        }
        .sheet(item: $vm.selectedAnnouncement) { announcement in
            AnnouncementSheetView(
                announcement: announcement,
                service: container.announcementService,
                session: session
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("Ок", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerSection
                mapCard(height: 286)
                VStack(alignment: .leading, spacing: 12) {
                    tasksHeader

                    if vm.visibleTasks.isEmpty {
                        roleEmptyCard
                    } else {
                        ForEach(vm.visibleTasks) { task in
                            RouteTaskBlock(
                                task: task,
                                isExpanded: vm.isExpanded(taskID: task.id),
                                onHeaderTap: {
                                    vm.toggleExpansion(for: task.id)
                                    vm.selectTask(task)
                                },
                                onOpenDetails: {
                                    guard let announcementID = task.announcementID else { return }
                                    Task { await vm.openTaskDetails(taskID: announcementID) }
                                },
                                onAcceptPreview: {
                                    Task { await vm.acceptPreviewTask(task.id) }
                                },
                                onRemoveAccepted: {
                                    Task { await vm.removeAcceptedTask(task.id) }
                                },
                                onStageSelect: { stage in
                                    Task { await vm.updateStage(taskID: task.id, stage: stage) }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, AppChrome.LiquidTabBar.contentClearance)
        }
        .refreshable {
            await vm.refresh()
        }
        .background(Theme.ColorToken.milk.ignoresSafeArea())
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                RouteRoleSwitcher(
                    selectedRole: vm.selectedRole,
                    onSelect: vm.switchRole
                )

                Spacer(minLength: 0)
            }

            if !vm.currentMetrics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.currentMetrics) { metric in
                            RouteMetricCard(metric: metric)
                        }
                    }
                }
            }
        }
    }

    private func mapCard(height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                    .fill(Theme.ColorToken.white)
                    .softCardShadow()

                RouteAppleMapView(
                    focusedCoordinate: $vm.focusedCoordinate,
                    markers: vm.mapMarkers,
                    selectedMarkerID: vm.selectedTaskID,
                    polylines: vm.mapPolylines,
                    shouldFitContents: vm.shouldFitRoute,
                    onRouteFitted: vm.consumeRouteFitRequest,
                    onMarkerTap: vm.selectPin(id:)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))

                if !vm.hasRenderableContent {
                    RouteUnavailableMapOverlay(
                        message: vm.emptyMessage,
                        onRefresh: {
                            Task { await vm.refresh() }
                        }
                    )
                    .padding(18)
                }

                if let note = vm.mapNote {
                    Text(note)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.62))
                        )
                        .padding(12)
                }
            }

            if vm.selectedRole == .performer, vm.canOpenInAppleMaps {
                Button {
                    vm.openCurrentRouteInAppleMaps()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 12, weight: .bold))

                        Text("Apple Maps")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.72))
                    )
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        }
        .frame(height: height)
    }

    private var tasksHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Задания")
                .font(.system(size: 19, weight: .bold))

            if !vm.visibleTasks.isEmpty {
                Text("\(vm.visibleTasks.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.ColorToken.white)
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var roleEmptyCard: some View {
        Text(vm.emptyMessage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ColorToken.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                    .fill(Theme.ColorToken.white)
            )
            .softCardShadow()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Собираем маршрут и задачи…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
    }
}

private struct RouteUnavailableMapOverlay: View {
    let message: String
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)

            Text("Маршрут пока недоступен")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ColorToken.textPrimary)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .multilineTextAlignment(.center)

            Button("Обновить", action: onRefresh)
                .buttonStyle(.borderedProminent)
                .tint(Theme.ColorToken.turquoise)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .fill(Theme.ColorToken.milk.opacity(0.94))
        )
    }
}

private struct RouteRoleSwitcher: View {
    let selectedRole: RouteViewModel.Role
    let onSelect: (RouteViewModel.Role) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RouteViewModel.Role.allCases) { role in
                Button {
                    onSelect(role)
                } label: {
                    Text(role.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(selectedRole == role ? Color.white : Theme.ColorToken.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(selectedRole == role ? Theme.ColorToken.turquoise : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Theme.ColorToken.white)
        )
        .overlay(
            Capsule()
                .stroke(Theme.ColorToken.turquoise.opacity(0.10), lineWidth: 1)
        )
        .softCardShadow()
    }
}

private struct RouteMetricCard: View {
    let metric: RouteViewModel.Metric

    var body: some View {
        HStack(spacing: 6) {
            Text(metric.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)

            Text(metric.value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ColorToken.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Theme.ColorToken.white)
        )
        .overlay(
            Capsule()
                .stroke(Theme.ColorToken.turquoise.opacity(0.08), lineWidth: 1)
        )
        .softCardShadow()
    }
}

private struct RouteTaskBlock: View {
    let task: RouteViewModel.TaskCard
    let isExpanded: Bool
    let onHeaderTap: () -> Void
    let onOpenDetails: () -> Void
    let onAcceptPreview: () -> Void
    let onRemoveAccepted: () -> Void
    let onStageSelect: (RouteViewModel.TaskStage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onHeaderTap) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(kindColor)
                        .frame(width: 12, height: 12)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(task.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.ColorToken.textPrimary)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 8)

                            Text(task.badgeTitle)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(kindColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(kindColor.opacity(0.12))
                                )
                        }

                        Text(task.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)

                        HStack(spacing: 8) {
                            if let priceText = task.priceText {
                                Text(priceText)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.ColorToken.turquoise)
                            }

                            if let detourText = task.detourText {
                                Text(detourText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.ColorToken.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.ColorToken.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(task.detailsText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textPrimary)
                        .multilineTextAlignment(.leading)

                    if let addressText = task.addressText {
                        Label(addressText, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }

                    HStack(spacing: 10) {
                        if task.announcementID != nil {
                            Button("Открыть карточку", action: onOpenDetails)
                                .font(.system(size: 13, weight: .bold))
                                .buttonStyle(.bordered)
                                .tint(Theme.ColorToken.turquoise)
                        }

                        if task.canRemoveFromRoute {
                            Button("Убрать из маршрута", action: onRemoveAccepted)
                                .font(.system(size: 13, weight: .bold))
                                .buttonStyle(.bordered)
                                .tint(.red)
                        }
                    }
                }
            }

            if !task.stageTitles.isEmpty {
                TaskStatusTimelineView(
                    titles: task.stageTitles,
                    selectedStage: task.stage,
                    nextSelectableStage: task.nextSelectableStage,
                    isInteractive: task.canUpdateStatus,
                    onSelect: onStageSelect
                )
            } else {
                PreviewBranchBar(
                    summary: task.previewSummary ?? "Рядом с основным маршрутом",
                    canAccept: task.canAcceptToRoute,
                    onAccept: onAcceptPreview
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .fill(Theme.ColorToken.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .stroke(kindColor.opacity(0.18), lineWidth: 1)
        )
        .softCardShadow()
    }

    private var kindColor: Color {
        switch task.kind {
        case .primary:
            return Theme.ColorToken.turquoise
        case .acceptedAdditional:
            return .green
        case .previewBranch:
            return Theme.ColorToken.peach
        case .customerObserved:
            return Theme.ColorToken.turquoise.opacity(0.8)
        }
    }
}

private struct PreviewBranchBar: View {
    let summary: String
    let canAccept: Bool
    let onAccept: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(summary)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(canAccept ? "Взять по пути" : "Лимит 2/2") {
                guard canAccept else { return }
                onAccept()
            }
            .font(.system(size: 13, weight: .bold))
            .buttonStyle(.borderedProminent)
            .tint(Theme.ColorToken.turquoise)
            .disabled(!canAccept)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.ColorToken.milk)
        )
    }
}

private struct TaskStatusTimelineView: View {
    let titles: [String]
    let selectedStage: RouteViewModel.TaskStage?
    let nextSelectableStage: RouteViewModel.TaskStage?
    let isInteractive: Bool
    let onSelect: (RouteViewModel.TaskStage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(RouteViewModel.TaskStage.allCases.enumerated()), id: \.element.id) { index, stage in
                        let isCompleted = selectedStage.map { stage.rawValue < $0.rawValue } ?? false
                        let isCurrent = selectedStage == stage
                        let isNext = nextSelectableStage == stage
                        let isEnabled = isInteractive && isNext

                        Button {
                            guard isEnabled else { return }
                            onSelect(stage)
                        } label: {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(circleFill(isCompleted: isCompleted, isCurrent: isCurrent, isNext: isNext))
                                        .frame(width: 22, height: 22)

                                    if isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(circleTextColor(isCurrent: isCurrent, isNext: isNext))
                                    }
                                }

                                Text(label(for: stage, index: index))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(labelColor(isCurrent: isCurrent, isCompleted: isCompleted, isNext: isNext))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(backgroundFill(isCurrent: isCurrent, isNext: isNext))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isNext ? Theme.ColorToken.turquoise.opacity(0.24) : .clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isEnabled)
                        .id(stage.id)
                    }
                }
            }
            .onAppear {
                scrollToFocusedStage(with: proxy, animated: false)
            }
            .onChange(of: selectedStage?.rawValue) { _ in
                scrollToFocusedStage(with: proxy, animated: true)
            }
            .onChange(of: nextSelectableStage?.rawValue) { _ in
                scrollToFocusedStage(with: proxy, animated: true)
            }
            .animation(.easeInOut(duration: 0.22), value: selectedStage?.rawValue)
            .animation(.easeInOut(duration: 0.22), value: nextSelectableStage?.rawValue)
        }
    }

    private func label(for stage: RouteViewModel.TaskStage, index: Int) -> String {
        if titles.indices.contains(index) {
            return titles[index]
        }
        return stage.id.description
    }

    private func circleFill(isCompleted: Bool, isCurrent: Bool, isNext: Bool) -> Color {
        if isCompleted || isCurrent {
            return Theme.ColorToken.turquoise
        }
        if isNext {
            return Theme.ColorToken.turquoise.opacity(0.16)
        }
        return Theme.ColorToken.milk
    }

    private func circleTextColor(isCurrent: Bool, isNext: Bool) -> Color {
        if isCurrent {
            return .white
        }
        if isNext {
            return Theme.ColorToken.turquoise
        }
        return Theme.ColorToken.textSecondary
    }

    private func labelColor(isCurrent: Bool, isCompleted: Bool, isNext: Bool) -> Color {
        if isCurrent || isCompleted {
            return Theme.ColorToken.textPrimary
        }
        if isNext {
            return Theme.ColorToken.turquoise
        }
        return Theme.ColorToken.textSecondary
    }

    private func backgroundFill(isCurrent: Bool, isNext: Bool) -> Color {
        if isCurrent {
            return Theme.ColorToken.turquoise.opacity(0.14)
        }
        if isNext {
            return Theme.ColorToken.turquoise.opacity(0.08)
        }
        return Theme.ColorToken.milk
    }

    private func scrollToFocusedStage(with proxy: ScrollViewProxy, animated: Bool) {
        guard let focusStage = selectedStage ?? nextSelectableStage else { return }
        let action = {
            proxy.scrollTo(focusStage.id, anchor: .center)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                action()
            }
        } else {
            action()
        }
    }
}
