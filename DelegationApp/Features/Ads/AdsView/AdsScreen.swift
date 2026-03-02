import SwiftUI

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Capsule().fill(color))
    }

    private var title: String {
        switch status {
        case "pending_review": return "На проверке"
        case "needs_fix": return "Нужно исправить"
        case "rejected": return "Отказано"
        case "archived": return "Архив"
        default: return "Активно"
        }
    }

    private var color: Color {
        switch status {
        case "pending_review": return Color.gray.opacity(0.75)
        case "needs_fix": return Color.yellow.opacity(0.8)
        case "rejected": return Color.red.opacity(0.85)
        case "archived": return Color.black.opacity(0.65)
        default: return Theme.ColorToken.turquoise
        }
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.secondary)
            Text("Здесь пока пусто")
                .font(.system(size: 16, weight: .bold))
            Text("Создайте объявление — оно появится в списке.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

struct StatPill: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .softCardShadow()
    }
}

struct MyAdsScreen: View {
    @StateObject private var vm: MyAdsViewModel
    @State private var selectedFilter: AdsFilter = .active
    @State private var showNewAdSheet: Bool = false

    init(vm: MyAdsViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                summarySection
                filterSegment
                listSection
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("Мои объявления")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .task { await vm.reload() }
        .refreshable { await vm.reload(showLoader: false) }
        .safeAreaInset(edge: .bottom) {
            newAdButton
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, 8)
                .padding(.bottom, 82)
                .background(Theme.ColorToken.milk.opacity(0.98))
        }
        .overlay(alignment: .top) {
            if let toast = vm.toastMessage {
                ToastBanner(message: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.toastMessage)
        .sheet(isPresented: $showNewAdSheet) {
            CreateAdFlowHost(
                service: vm.service,
                session: vm.session
            ) { created in
                selectedFilter = .actions
                vm.insertOptimistic(created)
            } onPublishCompletion: { localID, result in
                vm.resolveSubmission(localID: localID, result: result)
            }
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { vm.errorText != nil },
                set: { _ in vm.errorText = nil }
            )
        ) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text(vm.errorText ?? "")
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Статистика")
                .font(.system(size: 18, weight: .bold))

            HStack(spacing: 12) {
                StatPill(title: "Активные", value: vm.activeCount)
                StatPill(title: "Ждут", value: vm.actionsCount)
                StatPill(title: "Архив", value: vm.archivedCount)
            }
        }
        .padding(Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .fill(Color.white.opacity(0.6))
        )
        .softCardShadow()
    }

    private var filterSegment: some View {
        Picker("", selection: $selectedFilter) {
            Text("Активные").tag(AdsFilter.active)
            Text("Ждут действий").tag(AdsFilter.actions)
            Text("Архив").tag(AdsFilter.archived)
        }
        .pickerStyle(.segmented)
    }

    private var listSection: some View {
        let list = vm.filteredItems(for: selectedFilter)

        return Group {
            if vm.isLoading && vm.items.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загружаем объявления…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else if list.isEmpty {
                EmptyState()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(list) { item in
                        NavigationLink {
                            AnnouncementDetailsScreen(item: item, vm: vm)
                        } label: {
                            AnnouncementRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await vm.delete(item.id) }
                            } label: {
                                Text("Удалить")
                            }

                            Button {
                                Task { await vm.archive(item.id) }
                            } label: {
                                Text("Архив")
                            }
                            .tint(.gray)
                        }
                    }
                }
            }
        }
    }

    private var newAdButton: some View {
        Button {
            showNewAdSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Новое объявление")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                    .fill(Theme.ColorToken.turquoise)
            )
            .softCardShadow()
        }
    }
}

private struct AnnouncementRow: View {
    let item: AnnouncementDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AnnouncementImageView(
                url: item.previewImageURL,
                width: 84,
                height: 84,
                cornerRadius: 14
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        Text(categorySubtitle(item.category))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        if item.hasModerationIssues {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(item.maxReasonSeverity.color)
                        }
                        StatusBadge(status: item.normalizedStatus)
                    }
                }

                if let msg = item.decisionMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.ColorToken.turquoise.opacity(0.08), lineWidth: 1)
        )
        .softCardShadow()
    }

    private func categorySubtitle(_ raw: String) -> String {
        switch raw {
        case "delivery": return "Доставка и поручения"
        case "help": return "Помощь"
        default: return raw
        }
    }
}

private struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.82))
            )
            .softCardShadow()
    }
}
