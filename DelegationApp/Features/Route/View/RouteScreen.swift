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
            if vm.isLoading, vm.route == nil {
                loadingView
            } else if let errorMessage = vm.errorMessage {
                errorView(message: errorMessage)
            } else if let route = vm.route {
                content(route: route)
            } else {
                emptyView
            }
        }
        .navigationTitle("Маршрут")
        .task { await vm.load() }
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
                get: { vm.errorMessage != nil && vm.route != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("Ок", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func content(route: RouteDetailsDTO) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                summaryCard(route: route)

                mapCard

                tasksSection(route: route)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, AppChrome.LiquidTabBar.contentClearance)
        }
        .refreshable {
            await vm.refresh()
        }
    }

    private func summaryCard(route: RouteDetailsDTO) -> some View {
        VStack(spacing: 14) {
            RouteRow(symbol: "a.circle.fill", text: route.startAddress)
            RouteRow(symbol: "b.circle.fill", text: route.endAddress)

            Divider()

            HStack(spacing: 10) {
                Label(route.durationText, systemImage: "clock.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("•")
                    .foregroundStyle(Theme.ColorToken.textSecondary)
                Label(route.distanceText, systemImage: "arrow.forward.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Capsule()
                    .fill(Theme.ColorToken.milk)
                    .frame(width: 42, height: 30)
                    .overlay(
                        Text("\(route.tasksByRoute.count)")
                            .font(.system(size: 15, weight: .bold))
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .fill(Theme.ColorToken.white)
        )
        .softCardShadow()
    }

    private var mapCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .fill(Theme.ColorToken.white)
                .softCardShadow()

            MapCanvasView(
                centerPoint: .constant(nil),
                pins: vm.mapPins,
                selectedPinID: nil,
                routePolyline: vm.routePolyline,
                shouldFitRoute: vm.shouldFitRoute,
                onRouteFitted: vm.consumeRouteFitRequest,
                onPinTap: { _ in },
                mode: .real
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        }
        .frame(height: 250)
    }

    private func tasksSection(route: RouteDetailsDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Задания по пути")
                .font(.system(size: 20, weight: .bold))

            if route.tasksByRoute.isEmpty {
                Text("По пути пока нет подходящих заданий.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                            .fill(Theme.ColorToken.white)
                    )
                    .softCardShadow()
            } else {
                ForEach(route.tasksByRoute) { task in
                    Button {
                        Task { await vm.openTaskDetails(taskID: task.id) }
                    } label: {
                        RouteTaskCard(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Загружаем маршрут…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.peach)
            Text("Не удалось загрузить маршрут")
                .font(.system(size: 20, weight: .bold))
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Повторить") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.ColorToken.turquoise)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
            Text("Маршрут пока недоступен")
                .font(.system(size: 20, weight: .bold))
            Text(vm.emptyMessage ?? "У вас пока нет активного маршрута.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Обновить") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.ColorToken.turquoise)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
    }
}

private struct RouteRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.ColorToken.turquoise)
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RouteTaskCard: View {
    let task: TaskByRouteDTO

    var body: some View {
        HStack(spacing: 12) {
            AnnouncementImageView(
                url: task.previewURL,
                width: 92,
                height: 92,
                cornerRadius: 16
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let address = task.addressText, !address.isEmpty {
                    Text(address)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                        .lineLimit(2)
                }

                Text(task.distanceLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ColorToken.textSecondary)

                if let priceText = task.priceText, !priceText.isEmpty {
                    Text(priceText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.turquoise)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .fill(Theme.ColorToken.white)
        )
        .softCardShadow()
    }
}
