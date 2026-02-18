import SwiftUI

/// Экран "Мои объявления".
struct MyAdsScreen: View {
    @StateObject private var vm: MyAdsViewModel
    @State private var selectedFilter: AdsFilter = .active
    @State private var showNewAdSheet: Bool = false

    init(vm: MyAdsViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
            newAdButton
        }
        .navigationTitle("Мои объявления")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .task { await vm.reload() }
        .refreshable { await vm.reload() }
        .sheet(isPresented: $showNewAdSheet) {
            CreateAdFlowHost(
                service: vm.service,
                session: vm.session
            ) { _ in
                Task { await vm.reload() }
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

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                summarySection
                filtersSection
                listSection
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, 100)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Статистика")
                .font(.system(size: 18, weight: .bold))
            HStack(spacing: 12) {
                StatPill(title: "Активные", value: vm.activeCount)
                StatPill(title: "Черновики", value: vm.draftCount)
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

    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AdsFilter.allCases) { f in
                    FilterChip(
                        title: "\(f.rawValue) \(count(for: f))",
                        isSelected: selectedFilter == f
                    ) {
                        selectedFilter = f
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func count(for filter: AdsFilter) -> Int {
        switch filter {
        case .active: return vm.activeCount
        case .drafts: return vm.draftCount
        case .archived: return vm.archivedCount
        }
    }

    private var listSection: some View {
        Group {
            if vm.isLoading && vm.items.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загружаем объявления…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
            } else {
                let list = vm.filteredItems(for: selectedFilter)

                if list.isEmpty {
                    EmptyState()
                } else {
                    VStack(spacing: 12) {
                        ForEach(list) { item in
                            AnnouncementCard(item: item)
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
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, 90)
    }
}

// MARK: - UI bits

private struct StatPill: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.ColorToken.milk.opacity(0.65))
        )
    }
}

//private struct FilterChip: View {
//    let title: String
//    let isSelected: Bool
//    let tap: () -> Void
//
//    var body: some View {
//        Button(action: tap) {
//            Text(title)
//                .font(.system(size: 14, weight: .semibold))
//                .foregroundStyle(isSelected ? .white : .primary)
//                .padding(.vertical, 8)
//                .padding(.horizontal, 12)
//                .background(
//                    RoundedRectangle(cornerRadius: 14, style: .continuous)
//                        .fill(isSelected ? Theme.ColorToken.turquoise : Color.white.opacity(0.55))
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: 14, style: .continuous)
//                        .stroke(Theme.ColorToken.turquoise.opacity(0.25), lineWidth: 1)
//                )
//        }
//        .buttonStyle(.plain)
//    }
//}

private struct AnnouncementCard: View {
    let item: AnnouncementDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(categorySubtitle(item.category))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(status: item.status)
            }
        }
        .padding(Theme.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .fill(Color.white.opacity(0.6))
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

private struct StatusBadge: View {
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
        case "draft": return "Черновик"
        case "archived": return "Архив"
        default: return "Активно"
        }
    }

    private var color: Color {
        switch status {
        case "draft": return Color.gray.opacity(0.75)
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
            Text("Создайте первое объявление — оно появится в списке.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}
