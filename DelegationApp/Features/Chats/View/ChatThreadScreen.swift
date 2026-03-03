import SwiftUI

struct ChatThreadScreen: View {
    @StateObject private var vm: ChatThreadViewModel

    init(thread: ChatThreadPreview, service: ChatService, session: SessionStore) {
        _vm = StateObject(wrappedValue: ChatThreadViewModel(thread: thread, service: service, session: session))
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
        .task { await vm.loadMessages() }
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
                                MessageBubble(
                                    text: message.text,
                                    isCurrentUser: message.senderID == vm.currentUserID,
                                    timestamp: message.createdAt
                                )
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

private struct MessageBubble: View {
    let text: String
    let isCurrentUser: Bool
    let timestamp: Date

    var body: some View {
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
