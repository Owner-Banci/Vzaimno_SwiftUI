import SwiftUI

struct ProfileScreen: View {
    @StateObject private var vm: ProfileViewModel

    private let service: ProfileService
    private let session: SessionStore

    @State private var isPresentingEditProfile: Bool = false
    @State private var isPresentingAllReviews: Bool = false
    @State private var isShowingUserID: Bool = false

    init(service: ProfileService, session: SessionStore) {
        self.service = service
        self.session = session
        _vm = StateObject(wrappedValue: ProfileViewModel(service: service, session: session))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                profileSection
                settings
                support
                reviewsSection
            }
            .padding(.bottom, 32)
        }
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .navigationTitle("Профиль")
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.loadIfNeeded() }
        .refreshable { await vm.reload() }
        .alert("ID пользователя", isPresented: $isShowingUserID) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.profile?.userID ?? "")
        }
        .sheet(isPresented: $isPresentingEditProfile) {
            if let profile = vm.profile {
                NavigationStack {
                    ProfileEditScreen(
                        profile: profile,
                        service: service,
                        session: session,
                        onSaved: vm.didUpdateProfile
                    )
                }
            }
        }
        .sheet(isPresented: $isPresentingAllReviews) {
            NavigationStack {
                ProfileReviewsListScreen(service: service, session: session)
            }
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        switch vm.state {
        case .idle, .loading:
            loadingHeader

        case .loaded:
            if let profile = vm.profile {
                header(profile)
            }

        case .error(let message):
            errorCard(message: message)
        }
    }

    @ViewBuilder
    private var reviewsSection: some View {
        switch vm.state {
        case .idle, .loading:
            reviewsSkeleton

        case .loaded:
            SectionBox(title: "Отзывы") {
                if vm.reviews.isEmpty {
                    Text("У вас пока нет отзывов.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    ForEach(vm.reviews) { review in
                        ReviewRow(review: review)
                    }
                }

                Button("Посмотреть все отзывы") {
                    isPresentingAllReviews = true
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .tint(Theme.ColorToken.turquoise)
            }

        case .error:
            EmptyView()
        }
    }

    private func header(_ profile: UserProfile) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                isPresentingEditProfile = true
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 14) {
                        Circle()
                            .fill(Theme.ColorToken.milk)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Theme.ColorToken.turquoise)
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.resolvedDisplayName)
                                .font(.system(size: 20, weight: .semibold))
                                .multilineTextAlignment(.leading)

                            Text(profile.contactValue)
                                .foregroundStyle(.white.opacity(0.88))
                                .font(.system(size: 14))
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Theme.ColorToken.peach)
                                Text(profile.stats.ratingAverage, format: .number.precision(.fractionLength(1)))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text("\(profile.stats.ratingCount) оценок")
                                .foregroundStyle(.white.opacity(0.88))
                                .font(.system(size: 12))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(profile.stats.completedCount)")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Выполнено")
                                .foregroundStyle(.white.opacity(0.88))
                                .font(.system(size: 12))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(profile.stats.cancelledCount)")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Отменено")
                                .foregroundStyle(.white.opacity(0.88))
                                .font(.system(size: 12))
                        }

                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .buttonStyle(.plain)

            Button {
                isShowingUserID = true
            } label: {
                Text("ID")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.ColorToken.peach.opacity(0.3))
                    )
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [Theme.ColorToken.turquoise.opacity(0.85), Theme.ColorToken.turquoise],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 12)
        .softCardShadow()
    }

    private var loadingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 180, height: 20)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 140, height: 14)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 28) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 42, height: 16)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 72, height: 12)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Theme.ColorToken.turquoise.opacity(0.55), Theme.ColorToken.turquoise.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 12)
        .softCardShadow()
        .redacted(reason: .placeholder)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Не удалось загрузить профиль")
                .font(.system(size: 18, weight: .semibold))

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ColorToken.textSecondary)

            Button("Повторить") {
                Task { await vm.reload() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.ColorToken.turquoise)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.ColorToken.white)
        )
        .padding(.horizontal)
        .padding(.top, 12)
        .softCardShadow()
    }

    private var settings: some View {
        SectionBox(title: "Настройки") {
            ToggleRow(title: "Тёмная тема", isOn: $vm.darkMode)
            NavRow(title: "Уведомления")
            NavRow(title: "Платежи и выплаты")
        }
    }

    private var support: some View {
        SectionBox(title: "Поддержка") {
            NavRow(title: "Помощь")
            NavRow(title: "Правила и условия")
        }
    }

    private var reviewsSkeleton: some View {
        SectionBox(title: "Отзывы") {
            ForEach(0..<2, id: \.self) { _ in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Theme.ColorToken.milk)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.ColorToken.milk)
                            .frame(width: 140, height: 16)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.ColorToken.milk)
                            .frame(height: 14)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.ColorToken.milk)
                            .frame(width: 100, height: 12)
                    }
                }
                .padding()
                .redacted(reason: .placeholder)
            }
        }
    }
}

struct ReviewRow: View {
    let review: UserProfileReview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Theme.ColorToken.milk)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(review.authorInitials)
                        .font(.system(size: 16, weight: .bold))
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(review.authorName)
                        .font(.system(size: 15, weight: .semibold))
                    StarsView(rating: Double(review.stars))
                    Spacer(minLength: 0)
                }

                Text(review.text)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)

                Text(review.relativeCreatedAt)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}

private struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l)
                    .fill(Theme.ColorToken.white)
            )
            .softCardShadow()
            .padding(.horizontal)
        }
        .padding(.top, 4)
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Label(title, systemImage: "moon.fill")
                .labelStyle(.titleAndIcon)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding()
    }
}

private struct NavRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.ColorToken.textSecondary)
        }
        .padding()
    }
}
