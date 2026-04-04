import SwiftUI

struct ChatThreadScreen: View {
    @StateObject private var vm: ChatThreadViewModel

    init(thread: ChatThreadPreview, service: ChatService, profileService: ProfileService, session: SessionStore) {
        _vm = StateObject(wrappedValue: ChatThreadViewModel(thread: thread, service: service, profileService: profileService, session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            messagesArea
            composer
        }
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .hidesLiquidTabBar(reason: "chat-thread-screen")
        .task { await vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .sheet(isPresented: $vm.isPresentingReviewSheet) {
            if let context = vm.reviewContext {
                ChatReviewSheet(
                    counterpartName: context.counterpartDisplayName ?? "Пользователь",
                    counterpartRole: context.counterpartRole ?? .performer,
                    announcementTitle: context.announcementTitle
                ) { stars, text in
                    await vm.submitReview(stars: stars, text: text)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { vm.errorText != nil },
                set: { _ in vm.errorText = nil }
            )
        ) {
            Button("Ок", role: .cancel) { }
        } message: {
            Text(vm.errorText ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let url = vm.thread.partnerAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderAvatar
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                placeholderAvatar
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.thread.partnerName)
                    .font(.system(size: 18, weight: .bold))

                if let announcementTitle = vm.thread.announcementTitle, !announcementTitle.isEmpty {
                    Text(announcementTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.72))
    }

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            Group {
                if vm.isLoading && vm.messages.isEmpty {
                    ProgressView("Загружаем сообщения…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.messages.isEmpty {
                    VStack(spacing: 10) {
                        Text("Чат открыт")
                            .font(.system(size: 18, weight: .bold))
                        Text("Напишите первое сообщение собеседнику.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.messages) { message in
                                VStack(spacing: 8) {
                                    MessageBubble(
                                        text: message.text,
                                        isCurrentUser: message.senderID == vm.currentUserID,
                                        isSystem: message.isSystem,
                                        timestamp: message.createdAt
                                    )

                                    if vm.shouldShowReviewAction(for: message), let context = vm.reviewContext {
                                        ReviewActionCard(
                                            context: context,
                                            isSubmitting: vm.isSubmittingReview
                                        ) {
                                            vm.isPresentingReviewSheet = true
                                        }
                                    }
                                }
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Введите сообщение...", text: $vm.draftText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.ColorToken.turquoise.opacity(0.14), lineWidth: 1)
                )

            Button {
                Task { await vm.sendMessage() }
            } label: {
                Group {
                    if vm.isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(vm.canSend ? Theme.ColorToken.turquoise : Theme.ColorToken.textSecondary.opacity(0.35))
                )
            }
            .disabled(!vm.canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Theme.ColorToken.turquoise, Theme.ColorToken.peach],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(vm.thread.partnerInitials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = vm.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

private struct ReviewActionCard: View {
    let context: ReviewEligibility
    let isSubmitting: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(context.alreadySubmitted ? "Ваш отзыв уже отправлен" : "Оставьте отзыв о \(context.counterpartRole?.title.lowercased() ?? "пользователе")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textPrimary)

            if let message = context.message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
            }

            if context.canSubmit {
                Button {
                    onTap()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Оставить отзыв")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.ColorToken.turquoise)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ChatReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let counterpartName: String
    let counterpartRole: ReviewRole
    let announcementTitle: String?
    let onSubmit: (Int, String) async -> Bool

    @State private var selectedStars: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Оцените \(counterpartRole.title.lowercased())")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.ColorToken.textPrimary)

                        Text(counterpartName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textSecondary)

                        if let announcementTitle, !announcementTitle.isEmpty {
                            Text(announcementTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.ColorToken.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Рейтинг")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textSecondary)

                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    selectedStars = value
                                } label: {
                                    Image(systemName: value <= selectedStars ? "star.fill" : "star")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(value <= selectedStars ? Theme.ColorToken.peach : Theme.ColorToken.textSecondary.opacity(0.45))
                                        .frame(width: 42, height: 42)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(ratingCaption)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                            .fill(Theme.ColorToken.white)
                    )
                    .softCardShadow()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Комментарий")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textSecondary)

                        TextEditor(text: $comment)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                                    .fill(Theme.ColorToken.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                                    .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
                            )
                    }

                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Отправить отзыв")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.ColorToken.turquoise)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
                .padding(16)
            }
            .background(Theme.ColorToken.milk.ignoresSafeArea())
            .navigationTitle("Отзыв")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private var ratingCaption: String {
        switch selectedStars {
        case 5:
            return "Отлично"
        case 4:
            return "Хорошо"
        case 3:
            return "Нормально"
        case 2:
            return "Есть вопросы"
        default:
            return "Плохо"
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let ok = await onSubmit(selectedStars, comment)
        if ok {
            dismiss()
        } else {
            errorText = "Не удалось отправить отзыв. Попробуйте ещё раз."
        }
    }
}

private struct MessageBubble: View {
    let text: String
    let isCurrentUser: Bool
    let isSystem: Bool
    let timestamp: Date

    var body: some View {
        Group {
            if isSystem {
                VStack(spacing: 4) {
                    Text(text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)

                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.88))
                )
                .overlay(
                    Capsule()
                        .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
                )
            } else {
                HStack {
                    if isCurrentUser { Spacer(minLength: 48) }

                    VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                        Text(text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isCurrentUser ? .white : Theme.ColorToken.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isCurrentUser ? Color.white.opacity(0.75) : Theme.ColorToken.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isCurrentUser ? Theme.ColorToken.turquoise : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.ColorToken.turquoise.opacity(isCurrentUser ? 0 : 0.12), lineWidth: 1)
                    )

                    if !isCurrentUser { Spacer(minLength: 48) }
                }
            }
        }
    }
}
