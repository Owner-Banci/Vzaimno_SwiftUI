import Foundation

@MainActor
final class ChatThreadViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var draftText: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSending: Bool = false
    @Published private(set) var isLoadingReportOptions: Bool = false
    @Published private(set) var isSubmittingReport: Bool = false
    @Published private(set) var isSubmittingReview: Bool = false
    @Published private(set) var reviewContext: ReviewEligibility?
    @Published private(set) var reportReasonOptions: [ReportReasonOption] = []
    @Published var isPresentingReviewSheet: Bool = false
    @Published var isPresentingReportSheet: Bool = false
    @Published var errorText: String?

    let thread: ChatThreadPreview

    private let service: ChatService
    private let profileService: ProfileService
    private let session: SessionStore

    private var knownMessageIDs: Set<String> = []
    private var socketTask: URLSessionWebSocketTask?
    private var socketLoopTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var shouldKeepRealtimeConnection: Bool = false
    private var isRealtimeReady: Bool = false

    init(thread: ChatThreadPreview, service: ChatService, profileService: ProfileService, session: SessionStore) {
        self.thread = thread
        self.service = service
        self.profileService = profileService
        self.session = session
    }

    var currentUserID: String? {
        session.me?.id
    }

    var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var canPresentReportAction: Bool {
        resolvedReportTarget() != nil
    }

    var reportTargetSummary: String {
        resolvedReportTarget()?.summary ?? "Не удалось определить объект жалобы."
    }

    var availableReportReasonOptions: [ReportReasonOption] {
        guard let target = resolvedReportTarget() else { return reportReasonOptions }
        let filtered = reportReasonOptions.filter { $0.supports(targetType: target.type) }
        return filtered.isEmpty ? reportReasonOptions : filtered
    }

    func onAppear() async {
        shouldKeepRealtimeConnection = true
        isRealtimeReady = false
        await loadMessages()
        await loadReviewContext()
        startRefreshLoopIfNeeded()
        connectSocketIfNeeded()
    }

    func onDisappear() {
        shouldKeepRealtimeConnection = false
        disconnectSocket()
        stopRefreshLoop()
    }

    func loadMessages(showLoader: Bool = true) async {
        guard let token = session.token else {
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
            let fetched = try await fetchCurrentThreadMessages(token: token, limit: 50, before: nil)
            applyMessages(fetched)
            if fetched.contains(where: \.isSystem) {
                await loadReviewContext()
            }
            errorText = nil
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            errorText = error.localizedDescription
        }
    }

    func sendMessage() async {
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            return
        }

        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            let message = try await sendCurrentThreadMessage(token: token, text: text)
            appendMessageIfNeeded(message)
            draftText = ""
            errorText = nil
            connectSocketIfNeeded()
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            errorText = error.localizedDescription
        }
    }

    func loadReviewContext() async {
        guard let token = session.token else { return }
        guard let announcementID = thread.announcementID else {
            reviewContext = nil
            return
        }

        do {
            reviewContext = try await profileService.fetchReviewEligibility(token: token, announcementID: announcementID)
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            reviewContext = nil
        }
    }

    func shouldShowReviewAction(for message: ChatMessage) -> Bool {
        guard message.isSystem else { return false }
        guard let context = reviewContext else { return false }
        guard context.canSubmit || context.alreadySubmitted else { return false }
        guard message.text.localizedCaseInsensitiveContains("отзыв") else { return false }
        let latestReviewPromptID = messages.last {
            $0.isSystem && $0.text.localizedCaseInsensitiveContains("отзыв")
        }?.id
        return latestReviewPromptID == message.id
    }

    func submitReview(stars: Int, text: String) async -> Bool {
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            return false
        }
        guard let announcementID = thread.announcementID else {
            errorText = "Не удалось определить задание для отзыва."
            return false
        }

        isSubmittingReview = true
        defer { isSubmittingReview = false }

        do {
            try await profileService.submitReview(token: token, announcementID: announcementID, stars: stars, text: text)
            await loadReviewContext()
            return true
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return false
            }
            errorText = error.localizedDescription
            return false
        }
    }

    func presentReportSheet() async {
        guard canPresentReportAction else {
            errorText = "Не удалось определить объект жалобы в этом чате."
            return
        }
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            return
        }

        if reportReasonOptions.isEmpty {
            isLoadingReportOptions = true
            defer { isLoadingReportOptions = false }

            do {
                reportReasonOptions = try await service.fetchReportReasonOptions(token: token)
            } catch {
                if error.isUnauthorizedResponse {
                    await session.logout()
                    return
                }
                errorText = error.localizedDescription
                return
            }
        }

        if availableReportReasonOptions.isEmpty {
            errorText = "Для этого объекта сейчас нет доступных причин жалобы."
            return
        }

        isPresentingReportSheet = true
    }

    func submitReport(reasonCode: String, comment: String) async -> Bool {
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            return false
        }
        guard let target = resolvedReportTarget() else {
            errorText = "Не удалось определить объект жалобы."
            return false
        }

        let normalizedReasonCode = reasonCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedReasonCode.isEmpty else {
            errorText = "Выберите причину жалобы."
            return false
        }

        isSubmittingReport = true
        defer { isSubmittingReport = false }

        do {
            try await service.submitReport(
                token: token,
                targetType: target.type,
                targetID: target.id,
                reasonCode: normalizedReasonCode,
                reasonText: comment
            )
            isPresentingReportSheet = false
            return true
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return false
            }
            errorText = error.localizedDescription
            return false
        }
    }

    private func connectSocketIfNeeded() {
        guard socketTask == nil else { return }
        guard let token = session.token else { return }
        guard let url = makeSocketURL(token: token) else { return }

        isRealtimeReady = false

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let task = URLSession.shared.webSocketTask(with: request)
        socketTask = task
        task.resume()

        socketLoopTask = Task { [weak self, weak task] in
            guard let self, let task else { return }
            await self.receiveLoop(task: task)
        }
    }

    private func reconnectSocketIfNeeded() {
        guard shouldKeepRealtimeConnection else { return }
        guard socketTask == nil else { return }
        connectSocketIfNeeded()
    }

    private func disconnectSocket() {
        socketLoopTask?.cancel()
        socketLoopTask = nil

        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        isRealtimeReady = false
    }

    private func receiveLoop(task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let incoming = try await task.receive()
                guard socketTask === task else { return }
                handleSocketMessage(incoming)
            } catch {
                guard socketTask === task else { return }
                socketTask = nil
                socketLoopTask = nil
                isRealtimeReady = false

                guard shouldKeepRealtimeConnection else { return }
                await loadMessages(showLoader: false)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                reconnectSocketIfNeeded()
                return
            }
        }
    }

    private func handleSocketMessage(_ incoming: URLSessionWebSocketTask.Message) {
        switch incoming {
        case .string(let text):
            processSocketText(text)
        case .data(let data):
            processSocketData(data)
        @unknown default:
            break
        }
    }

    private func processSocketText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        processSocketData(data)
    }

    private func processSocketData(_ data: Data) {
        guard let envelope = try? JSONDecoder().decode(SocketEnvelope.self, from: data) else {
            return
        }

        switch envelope.type {
        case "ready":
            isRealtimeReady = true
        case "message":
            isRealtimeReady = true
            guard let dto = envelope.payload else { return }
            appendMessageIfNeeded(dto.domain)
        case "error":
            if let message = envelope.message, !message.isEmpty {
                errorText = message
            }
        default:
            break
        }
    }

    private func makeSocketURL(token: String) -> URL? {
        var components = URLComponents(
            url: AppConfig.webSocketBaseURL.appendingPathComponent("ws/chats/\(thread.threadID)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        return components?.url
    }

    private func applyMessages(_ fetched: [ChatMessage]) {
        messages = fetched.sorted { $0.createdAt < $1.createdAt }
        knownMessageIDs = Set(messages.map(\.id))
    }

    private func appendMessageIfNeeded(_ message: ChatMessage) {
        let insertion = knownMessageIDs.insert(message.id)
        guard insertion.inserted else { return }

        messages.append(message)
        messages.sort { $0.createdAt < $1.createdAt }
        if message.isSystem {
            Task { await loadReviewContext() }
        }
        ChatRealtimeBroker.publish(
            ChatThreadActivity(
                threadID: thread.threadID,
                text: message.text,
                createdAt: message.createdAt,
                senderID: message.senderID,
                incrementUnread: false
            )
        )
    }

    private func startRefreshLoopIfNeeded() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, let self else { break }
                guard self.shouldKeepRealtimeConnection else { continue }
                guard !self.isRealtimeReady || self.socketTask == nil else { continue }
                await self.loadMessages(showLoader: false)
            }
        }
    }

    private func fetchCurrentThreadMessages(token: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        if thread.kind == "support" {
            return try await service.fetchSupportMessages(token: token, threadID: thread.threadID, limit: limit, before: before)
        }
        return try await service.fetchMessages(token: token, threadID: thread.threadID, limit: limit, before: before)
    }

    private func sendCurrentThreadMessage(token: String, text: String) async throws -> ChatMessage {
        if thread.kind == "support" {
            return try await service.sendSupportMessage(token: token, threadID: thread.threadID, text: text)
        }
        return try await service.sendMessage(token: token, threadID: thread.threadID, text: text)
    }

    private func resolvedReportTarget() -> ReportTarget? {
        if let message = messages.last(where: { !$0.isSystem && $0.senderID != currentUserID }) {
            return ReportTarget(
                type: "message",
                id: message.id,
                summary: "Жалоба будет связана с последним сообщением собеседника."
            )
        }

        if let partnerID = normalizedIdentifier(thread.partnerID) {
            return ReportTarget(
                type: "user",
                id: partnerID,
                summary: "Жалоба будет отправлена на пользователя \(thread.partnerName)."
            )
        }

        if let announcementID = normalizedIdentifier(thread.announcementID) {
            return ReportTarget(
                type: "task",
                id: announcementID,
                summary: "Жалоба будет связана с заданием \(thread.announcementTitle ?? "без названия")."
            )
        }

        return nil
    }

    private func stopRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

private struct SocketEnvelope: Decodable {
    let type: String
    let payload: ChatMessageDTO?
    let message: String?
}

private struct ReportTarget {
    let type: String
    let id: String
    let summary: String
}

private func normalizedIdentifier(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
