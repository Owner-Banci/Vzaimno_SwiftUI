import SwiftUI

struct ProfileEditScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: EditProfileViewModel

    init(
        profile: UserProfile,
        service: ProfileService,
        session: SessionStore,
        onSaved: @escaping (UserProfile) -> Void
    ) {
        _vm = StateObject(
            wrappedValue: EditProfileViewModel(
                profile: profile,
                service: service,
                session: session,
                onSaved: onSaved
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                identitySection
                aboutSection
                locationSection
                statsSection
                if let formError = vm.formError {
                    ErrorBanner(message: formError)
                }
                logoutSection
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .navigationTitle("Редактировать профиль")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(vm.isBusy)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    dismiss()
                }
                .disabled(vm.isBusy)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        if await vm.save() {
                            dismiss()
                        }
                    }
                } label: {
                    if vm.isSaving {
                        ProgressView()
                    } else {
                        Text("Сохранить")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(vm.isBusy)
            }
        }
        .alert("Вы уверены? Нужно будет войти снова.", isPresented: $vm.isLogoutConfirmationPresented) {
            Button("Отмена", role: .cancel) { }
            Button("Выйти", role: .destructive) {
                Task { await vm.logout() }
            }
        }
    }

    private var identitySection: some View {
        FormSectionCard(title: "Основное") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Имя")
                    .font(.system(size: 14, weight: .semibold))

                TextField("Введите имя", text: $vm.displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .fieldStyle()

                ValidationText(message: vm.displayNameError)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(vm.contactTitle)
                    .font(.system(size: 14, weight: .semibold))

                Text(vm.contactValue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.m)
                            .fill(Theme.ColorToken.milk)
                    )

                Text(vm.contactCaption)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
            }
        }
    }

    private var aboutSection: some View {
        FormSectionCard(title: "О себе") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Город")
                    .font(.system(size: 14, weight: .semibold))

                TextField("Например, Москва", text: $vm.city)
                    .textInputAutocapitalization(.words)
                    .fieldStyle()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Описание")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(vm.bioCounterText)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                }

                TextEditor(text: $vm.bio)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.m)
                            .strokeBorder(Theme.ColorToken.shadow, lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.m)
                                    .fill(Theme.ColorToken.white)
                            )
                    )

                ValidationText(message: vm.bioError)
            }
        }
    }

    private var locationSection: some View {
        FormSectionCard(title: "Самый удобный адрес") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Самый удобный адрес")
                    .font(.system(size: 14, weight: .semibold))

                TextField("Например, Москва, ул. Тверская, 1", text: $vm.preferredAddress, axis: .vertical)
                    .lineLimit(2...4)
                    .fieldStyle()
            }

            Text("Укажите адрес, с которого вам удобнее всего взаимодействовать с исполнителем или заказчиком.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ColorToken.textSecondary)

            ValidationText(message: vm.preferredAddressError)
        }
    }

    private var statsSection: some View {
        FormSectionCard(title: "Статистика") {
            ReadOnlyStatRow(title: "Рейтинг", value: vm.stats.ratingAverage.formatted(.number.precision(.fractionLength(1))))
            ReadOnlyStatRow(title: "Количество оценок", value: "\(vm.stats.ratingCount)")
            ReadOnlyStatRow(title: "Выполнено", value: "\(vm.stats.completedCount)")
            ReadOnlyStatRow(title: "Отменено", value: "\(vm.stats.cancelledCount)")
        }
    }

    private var logoutSection: some View {
        Button(role: .destructive) {
            vm.isLogoutConfirmationPresented = true
        } label: {
            HStack {
                if vm.isLoggingOut {
                    ProgressView()
                }
                Text("Выйти из аккаунта")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(vm.isBusy)
        .padding(.top, 4)
    }
}

private struct FormSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l)
                    .fill(Theme.ColorToken.white)
            )
            .softCardShadow()
        }
    }
}

private struct ValidationText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.red)
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .fill(Color.red.opacity(0.08))
            )
    }
}

private struct ReadOnlyStatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.vertical, 2)
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .strokeBorder(Theme.ColorToken.shadow, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.m)
                            .fill(Theme.ColorToken.white)
                    )
            )
    }
}
