import SwiftUI

struct ProfileReviewsListScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ProfileReviewsListViewModel

    init(service: ProfileService, session: SessionStore, initialRole: ReviewRole = .performer) {
        _vm = StateObject(wrappedValue: ProfileReviewsListViewModel(service: service, session: session, initialRole: initialRole))
    }

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView("Загружаем отзывы…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                if vm.reviews.isEmpty {
                    VStack(spacing: 16) {
                        rolePicker
                        summaryCard
                        ContentUnavailableView(
                            "Пока нет отзывов",
                            systemImage: "text.bubble",
                            description: Text("Как только вас оценят как \(vm.selectedRole.title.lowercased()), отзывы появятся здесь.")
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 24)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            rolePicker
                            summaryCard
                            ForEach(vm.reviews) { review in
                                ReviewRow(review: review)
                                    .padding(.horizontal, 12)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Theme.ColorToken.milk.ignoresSafeArea())
                }

            case .error(let message):
                VStack(spacing: 12) {
                    Text("Не удалось загрузить отзывы")
                        .font(.system(size: 18, weight: .semibold))
                    Text(message)
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                    Button("Повторить") {
                        Task { await vm.reload() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.ColorToken.turquoise)
                }
                .padding(24)
            }
        }
        .navigationTitle("Все отзывы")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") { dismiss() }
            }
        }
        .task { await vm.loadIfNeeded() }
    }

    private var rolePicker: some View {
        Picker("", selection: $vm.selectedRole) {
            ForEach(ReviewRole.allCases) { role in
                Text(role.title).tag(role)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .onChange(of: vm.selectedRole) { _, role in
            Task { await vm.selectRole(role) }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Рейтинг как \(vm.selectedRole.title.lowercased())")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(vm.summary.average.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.ColorToken.textPrimary)

                StarsView(rating: vm.summary.average)

                Spacer(minLength: 0)
            }

            Text("\(vm.summary.count) оценок")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .fill(Theme.ColorToken.white)
        )
        .softCardShadow()
        .padding(.horizontal, 16)
    }
}
