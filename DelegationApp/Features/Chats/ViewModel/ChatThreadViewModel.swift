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
    @Published var isPresentingOpenDisputeSheet: Bool = false
    @Published var isPresentingCounterpartySheet: Bool = false
    @Published private(set) var activeDispute: DisputeState?
    @Published private(set) var isLoadingDispute: Bool = false
    @Published private(set) var isSubmittingDisputeAction: Bool = false
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
    private var socketFailureCount: Int = 0
    private var socketBackoffUntil: Date = .distantPast
    private var pollingIntervalSeconds: TimeInterval = 2
    private let minPollingIntervalSeconds: TimeInterval = 2
    private let maxPollingIntervalSeconds: TimeInterval = 30
    private var isWebSocketAllowedByServer: Bool = true
    private var hasLoadedRealtimeCapabilities: Bool = false

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

    var shouldShowDisputeThinkingState: Bool {
        activeDispute?.isModelThinking == true
    }

    var canShowOpenDisputeAction: Bool {
        guard thread.kind != "support" else { return false }
        if let activeDispute {
            return activeDispute.canOpenNewDispute
        }
        return true
    }

    var canRespondAsCounterparty: Bool {
        guard let activeDispute else { return false }
        return activeDispute.isWaitingCounterparty && activeDispute.viewerSide == "counterparty"
    }

    var canVoteInCurrentRound: Bool {
        guard let activeDispute else { return false }
        guard activeDispute.viewerPartyRole == "customer" || activeDispute.viewerPartyRole == "performer" else {
            return false
        }
        return activeDispute.isWaitingRound1Votes || activeDispute.isWaitingRound2Votes
    }

    var canAnswerClarifications: Bool {
        guard let activeDispute else { return false }
        guard activeDispute.isWaitingClarificationAnswers else { return false }
        guard let viewerPartyRole = activeDispute.viewerPartyRole else { return false }
        return activeDispute.requiredAnswerPartyRoles.contains(viewerPartyRole)
            && !activeDispute.questions.isEmpty
    }

    var disputeDeadlineText: String? {
        guard let deadline = activeDispute?.counterpartyDeadlineAt else { return nil }
        let now = Date()
        let seconds = Int(deadline.timeIntervalSince(now))
        if seconds <= 0 {
            return "Срок ответа истёк"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        }
        return "\(minutes) мин"
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
        resetRealtimeBackoff()
        isRealtimeReady = false
        await refreshRealtimeCapabilitiesIfNeeded(force: true)
        await loadMessages()
        if reviewContext == nil {
            await loadReviewContext()
        }
        startRefreshLoopIfNeeded()
        connectSocketIfNeeded(force: true)
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
            let previousLatestSystemID = latestSystemMessageID(in: messages)
            let fetched = try await fetchCurrentThreadMessages(token: token, limit: 50, before: nil)
            applyMessages(fetched)
            let currentLatestSystemID = latestSystemMessageID(in: messages)
            if reviewContext == nil || currentLatestSystemID != previousLatestSystemID {
                await loadReviewContext()
            }
            await loadActiveDispute(showLoader: false)
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
            pollingIntervalSeconds = minPollingIntervalSeconds
            await loadActiveDispute(showLoader: false)
            errorText = nil
            connectSocketIfNeeded(force: true)
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            errorText = error.localizedDescription
        }
    }

    func loadActiveDispute(showLoader: Bool = false) async {
        guard thread.kind != "support" else {
            activeDispute = nil
            return
        }
        guard let token = session.token else {
            activeDispute = nil
            return
        }

        if showLoader {
            isLoadingDispute = true
        }
        defer {
            if showLoader {
                isLoadingDispute = false
            }
        }

        do {
            activeDispute = try await service.fetchActiveDispute(token: token, threadID: thread.threadID)
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            if !error.isForbiddenResponse {
                errorText = error.localizedDescription
            }
        }
    }

    func openDispute(
        problemTitle: String,
        problemDescription: String,
        requestedCompensationRub: Int,
        desiredResolution: String
    ) async -> Bool {
        guard let token = session.token else {
            errorText = "Сессия не найдена. Войдите снова."
            return false
        }
        isSubmittingDisputeAction = true
        defer { isSubmittingDisputeAction = false }

        do {
            activeDispute = try await service.openDispute(
                token: token,
                threadID: thread.threadID,
                problemTitle: problemTitle,
                problemDescription: problemDescription,
                requestedCompensationRub: requestedCompensationRub,
                desiredResolution: desiredResolution
            )
            isPresentingOpenDisputeSheet = false
            await loadMessages(showLoader: false)
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

    func acceptCounterpartyTerms() async -> Bool {
        guard let token = session.token, let activeDispute else {
            errorText = "Не найден активный спор."
            return false
        }
        isSubmittingDisputeAction = true
        defer { isSubmittingDisputeAction = false }

        do {
            self.activeDispute = try await service.acceptCounterpartyDispute(
                token: token,
                threadID: thread.threadID,
                disputeID: activeDispute.id
            )
            isPresentingCounterpartySheet = false
            await loadMessages(showLoader: false)
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

    func submitCounterpartyResponse(
        responseDescription: String,
        acceptableRefundPercent: Int,
        desiredResolution: String
    ) async -> Bool {
        guard let token = session.token, let activeDispute else {
            errorText = "Не найден активный спор."
            return false
        }
        isSubmittingDisputeAction = true
        defer { isSubmittingDisputeAction = false }

        do {
            self.activeDispute = try await service.respondCounterpartyDispute(
                token: token,
                threadID: thread.threadID,
                disputeID: activeDispute.id,
                responseDescription: responseDescription,
                acceptableRefundPercent: acceptableRefundPercent,
                desiredResolution: desiredResolution
            )
            isPresentingCounterpartySheet = false
            await loadMessages(showLoader: false)
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

    func selectDisputeOption(optionID: String) async -> Bool {
        guard let token = session.token, let activeDispute else {
            errorText = "Не найден активный спор."
            return false
        }
        isSubmittingDisputeAction = true
        defer { isSubmittingDisputeAction = false }

        do {
            self.activeDispute = try await service.selectDisputeOption(
                token: token,
                threadID: thread.threadID,
                disputeID: activeDispute.id,
                optionID: optionID
            )
            await loadMessages(showLoader: false)
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

    func shouldShowCounterpartyTapTarget(for message: ChatMessage) -> Bool {
        guard let activeDispute, canRespondAsCounterparty else { return false }
        guard message.isSystem else { return false }
        guard message.text.localizedCaseInsensitiveContains("спор") else { return false }
        guard activeDispute.openedByDisplayName.isEmpty == false else { return false }
        return message.text.localizedCaseInsensitiveContains(activeDispute.openedByDisplayName)
            || message.text.localizedCaseInsensitiveContains("открыл")
    }

    func openCounterpartySheetFromSystemMessage() {
        guard canRespondAsCounterparty else { return }
        isPresentingCounterpartySheet = true
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

    private func connectSocketIfNeeded(force: Bool = false) {
        guard socketTask == nil else { return }
        guard let token = session.token else { return }
        guard let url = makeSocketURL(token: token) else { return }
        guard isWebSocketAllowedByServer else { return }
        if !force, Date() < socketBackoffUntil { return }

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
        guard isWebSocketAllowedByServer else { return }
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
                socketFailureCount += 1
                let exponent = min(socketFailureCount, 6)
                let delay = min(pow(2.0, Double(exponent)), 60.0)
                socketBackoffUntil = Date().addingTimeInterval(delay)
                pollingIntervalSeconds = min(maxPollingIntervalSeconds, max(minPollingIntervalSeconds, delay))

                guard shouldKeepRealtimeConnection else { return }
                await loadMessages(showLoader: false)
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
            socketFailureCount = 0
            socketBackoffUntil = .distantPast
            pollingIntervalSeconds = minPollingIntervalSeconds
        case "message":
            isRealtimeReady = true
            socketFailureCount = 0
            socketBackoffUntil = .distantPast
            pollingIntervalSeconds = minPollingIntervalSeconds
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
            Task {
                await loadReviewContext()
                await loadActiveDispute(showLoader: false)
            }
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
                let interval = max(minPollingIntervalSeconds, min(maxPollingIntervalSeconds, pollingIntervalSeconds))
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self else { break }
                guard self.shouldKeepRealtimeConnection else { continue }
                if self.isRealtimeReady, self.socketTask != nil {
                    self.pollingIntervalSeconds = self.minPollingIntervalSeconds
                    continue
                }
                await self.loadMessages(showLoader: false)
                self.pollingIntervalSeconds = min(
                    self.maxPollingIntervalSeconds,
                    max(self.minPollingIntervalSeconds, self.pollingIntervalSeconds * 1.6)
                )
                self.reconnectSocketIfNeeded()
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

    private func refreshRealtimeCapabilitiesIfNeeded(force: Bool = false) async {
        guard let token = session.token else { return }
        if hasLoadedRealtimeCapabilities && !force { return }

        do {
            let capabilities = try await service.fetchRealtimeCapabilities(token: token)
            isWebSocketAllowedByServer = capabilities.chatWebSocketEnabled
            hasLoadedRealtimeCapabilities = true
        } catch {
            // Если endpoint недоступен (старый backend), пробуем websocket как раньше.
            isWebSocketAllowedByServer = true
        }
    }

    private func resetRealtimeBackoff() {
        socketFailureCount = 0
        socketBackoffUntil = .distantPast
        pollingIntervalSeconds = minPollingIntervalSeconds
    }

    private func latestSystemMessageID(in source: [ChatMessage]) -> String? {
        source.last { $0.isSystem }?.id
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
