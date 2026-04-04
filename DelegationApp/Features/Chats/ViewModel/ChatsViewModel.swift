import Foundation

@MainActor
final class ChatsViewModel: ObservableObject {
    @Published private(set) var chats: [ChatThreadPreview] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorText: String?

    private let service: ChatService
    private let session: SessionStore
    private var observer: NSObjectProtocol?
    private var autoRefreshTask: Task<Void, Never>?

    init(service: ChatService, session: SessionStore) {
        self.service = service
        self.session = session
        self.observer = NotificationCenter.default.addObserver(
            forName: ChatRealtimeBroker.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let activity = ChatRealtimeBroker.activity(from: notification) else { return }
            Task { @MainActor [weak self] in
                self?.apply(activity: activity)
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        autoRefreshTask?.cancel()
    }

    func reload(showLoader: Bool = true) async {
        guard let token = session.token else {
            chats = []
            errorText = "Сессия не найдена. Войдите снова."
            return
        }

        if showLoader {
            isLoading = true
        }
        defer {
            if showLoader {
                isLoading = false
            }
        }

        do {
            chats = try await service.fetchThreads(token: token)
            errorText = nil
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            errorText = error.localizedDescription
        }
    }

    func onAppear() {
        guard autoRefreshTask == nil else { return }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard !Task.isCancelled, let self else { break }
                await self.reload(showLoader: false)
            }
        }
    }

    func onDisappear() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func apply(activity: ChatThreadActivity) {
        guard let index = chats.firstIndex(where: { $0.threadID == activity.threadID }) else { return }

        let current = chats[index]
        let unreadCount = activity.incrementUnread && activity.senderID != session.me?.id
            ? current.unreadCount + 1
            : current.unreadCount

        chats[index] = ChatThreadPreview(
            threadID: current.threadID,
            kind: current.kind,
            partnerID: current.partnerID,
            partnerName: current.partnerName,
            partnerAvatarURL: current.partnerAvatarURL,
            lastMessageText: activity.text,
            lastMessageAt: activity.createdAt,
            unreadCount: unreadCount,
            announcementID: current.announcementID,
            announcementTitle: current.announcementTitle
        )
        chats.sort { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
    }
}
