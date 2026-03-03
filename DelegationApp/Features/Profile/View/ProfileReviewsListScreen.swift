import SwiftUI

struct ProfileReviewsListScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: ProfileReviewsListViewModel

    init(service: ProfileService, session: SessionStore) {
        _vm = StateObject(wrappedValue: ProfileReviewsListViewModel(service: service, session: session))
    }

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView("Загружаем отзывы…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                if vm.reviews.isEmpty {
                    ContentUnavailableView(
                        "Пока нет отзывов",
                        systemImage: "text.bubble",
                        description: Text("Как только вас оценят, отзывы появятся здесь.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
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
}
