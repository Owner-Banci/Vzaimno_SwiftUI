import Foundation

@MainActor
final class ChatThreadViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var draftText: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSending: Bool = false
    @Published var errorText: String?

    let thread: ChatThreadPreview

    private let service: ChatService
    private let session: SessionStore

    private var knownMessageIDs: Set<String> = []
    private var socketTask: URLSessionWebSocketTask?
    private var socketLoopTask: Task<Void, Never>?
    private var shouldKeepRealtimeConnection: Bool = false

    init(thread: ChatThreadPreview, service: ChatService, session: SessionStore) {
        self.thread = thread
        self.service = service
        self.session = session
    }

    var currentUserID: String? {
        session.me?.id
    }

    var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func onAppear() async {
        shouldKeepRealtimeConnection = true
        await loadMessages()
        connectSocketIfNeeded()
    }

    func onDisappear() {
        shouldKeepRealtimeConnection = false
        disconnectSocket()
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
            let fetched = try await service.fetchMessages(token: token, threadID: thread.threadID, limit: 50, before: nil)
            applyMessages(fetched)
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
            let message = try await service.sendMessage(token: token, threadID: thread.threadID, text: text)
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

    private func connectSocketIfNeeded() {
        guard socketTask == nil else { return }
        guard let token = session.token else { return }
        guard let url = makeSocketURL(token: token) else { return }

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

                guard shouldKeepRealtimeConnection else { return }
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
        case "message":
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
    }
}

private struct SocketEnvelope: Decodable {
    let type: String
    let payload: ChatMessageDTO?
    let message: String?
}
