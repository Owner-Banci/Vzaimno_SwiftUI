import SwiftUI

struct ChatsScreen: View {
    @StateObject private var vm: ChatsViewModel
    private let service: ChatService
    private let profileService: ProfileService
    private let session: SessionStore

    init(service: ChatService, profileService: ProfileService, session: SessionStore) {
        self.service = service
        self.profileService = profileService
        self.session = session
        _vm = StateObject(wrappedValue: ChatsViewModel(service: service, session: session))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.chats.isEmpty {
                ProgressView("Загружаем чаты…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.ColorToken.milk)
            } else if vm.chats.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.chats) { chat in
                        NavigationLink {
                            ChatThreadScreen(thread: chat, service: service, profileService: profileService, session: session)
                        } label: {
                            ChatThreadRow(chat: chat)
                        }
                        .listRowBackground(Theme.ColorToken.white)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Theme.ColorToken.milk)
            }
        }
        .navigationTitle("Сообщения")
        .task {
            vm.onAppear()
            await vm.reload()
        }
        .onDisappear {
            vm.onDisappear()
        }
        .refreshable { await vm.reload(showLoader: false) }
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
        .background(Theme.ColorToken.milk.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
            Text("Чатов пока нет")
                .font(.system(size: 18, weight: .bold))
            Text("Когда ваш отклик примут, диалог появится здесь.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ColorToken.milk)
    }
}

private struct ChatThreadRow: View {
    let chat: ChatThreadPreview

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(chat: chat)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chat.partnerName)
                            .font(.system(size: 16, weight: .semibold))

                        if let announcementTitle = chat.announcementTitle, !announcementTitle.isEmpty {
                            Text(announcementTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.ColorToken.textSecondary)
                        }
                    }

                    Spacer()

                    Text(chat.formattedTime)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                }

                Text(chat.lastMessageText)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
                    .lineLimit(1)
            }

            if chat.unreadCount > 0 {
                Text("\(chat.unreadCount)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(Theme.ColorToken.turquoise))
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AvatarView: View {
    let chat: ChatThreadPreview

    var body: some View {
        Group {
            if let url = chat.partnerAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsPlaceholder
                    }
                }
            } else {
                initialsPlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }

    private var initialsPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Theme.ColorToken.turquoise, Theme.ColorToken.peach],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(chat.partnerInitials)
                    .foregroundStyle(.white)
                    .font(.system(size: 17, weight: .bold))
            )
    }
}
