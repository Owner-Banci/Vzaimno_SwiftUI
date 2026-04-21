import Foundation

final class MockChatService: ChatService {
    func fetchThreads(token: String) async throws -> [ChatThreadPreview] {
        [
            ChatThreadPreview(
                threadID: UUID().uuidString,
                kind: "support",
                partnerID: "support-1",
                partnerName: "Поддержка Vzaimno",
                partnerAvatarURL: nil,
                lastMessageText: "Здравствуйте! Чем можем помочь?",
                lastMessageAt: .now,
                unreadCount: 1,
                announcementID: nil,
                announcementTitle: nil,
                isPinned: true
            ),
            ChatThreadPreview(
                threadID: UUID().uuidString,
                kind: "offer",
                partnerID: "mock-1",
                partnerName: "Саша",
                partnerAvatarURL: nil,
                lastMessageText: "Ман сасилдок",
                lastMessageAt: .now,
                unreadCount: 1,
                announcementID: "mock-task-1",
                announcementTitle: "Доставка посылки",
                isPinned: false
            ),
            ChatThreadPreview(
                threadID: UUID().uuidString,
                kind: "offer",
                partnerID: "mock-2",
                partnerName: "Павел",
                partnerAvatarURL: nil,
                lastMessageText: "Посылку доставил",
                lastMessageAt: Date().addingTimeInterval(-86_400),
                unreadCount: 0,
                announcementID: "mock-task-2",
                announcementTitle: "Помочь донести сумки",
                isPinned: false
            ),
        ]
    }

    func fetchRealtimeCapabilities(token: String) async throws -> ChatRealtimeCapabilities {
        ChatRealtimeCapabilities(chatWebSocketEnabled: false, websocketPath: "/ws/chats/{thread_id}")
    }

    func fetchMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        [
            ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "mock-1", text: "Здравствуйте", createdAt: Date().addingTimeInterval(-300)),
            ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "dev", text: "Добрый день", createdAt: Date().addingTimeInterval(-120)),
        ]
    }

    func sendMessage(token: String, threadID: String, text: String) async throws -> ChatMessage {
        ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "dev", text: text, createdAt: .now)
    }

    func fetchActiveDispute(token: String, threadID: String) async throws -> DisputeState? {
        nil
    }

    func openDispute(
        token: String,
        threadID: String,
        problemTitle: String,
        problemDescription: String,
        requestedCompensationRub: Int,
        desiredResolution: String
    ) async throws -> DisputeState {
        DisputeState(
            id: UUID().uuidString,
            threadID: threadID,
            status: "open_waiting_counterparty",
            initiatorUserID: "dev",
            counterpartyUserID: "mock-1",
            initiatorPartyRole: "customer",
            viewerSide: "initiator",
            viewerPartyRole: "customer",
            openedByDisplayName: "Тестовый пользователь",
            counterpartyDeadlineAt: Date().addingTimeInterval(48 * 3600),
            activeRound: 1,
            isModelThinking: false,
            resolutionSummary: nil,
            selectedOptionID: nil,
            moderatorRequired: false,
            questions: [],
            requiredAnswerPartyRoles: [],
            options: [],
            votes: [:],
            myVoteOptionID: nil,
            initiatorTerms: DisputeInitiatorTerms(
                requestedCompensationRub: requestedCompensationRub,
                desiredResolution: desiredResolution,
                problemTitle: problemTitle
            ),
            lastModelError: nil
        )
    }

    func acceptCounterpartyDispute(token: String, threadID: String, disputeID: String) async throws -> DisputeState {
        DisputeState(
            id: disputeID,
            threadID: threadID,
            status: "closed_by_acceptance",
            initiatorUserID: "mock-1",
            counterpartyUserID: "dev",
            initiatorPartyRole: "customer",
            viewerSide: "counterparty",
            viewerPartyRole: "performer",
            openedByDisplayName: "Тестовый пользователь",
            counterpartyDeadlineAt: nil,
            activeRound: 1,
            isModelThinking: false,
            resolutionSummary: "Тестовое закрытие по согласию",
            selectedOptionID: nil,
            moderatorRequired: false,
            questions: [],
            requiredAnswerPartyRoles: [],
            options: [],
            votes: [:],
            myVoteOptionID: nil,
            initiatorTerms: DisputeInitiatorTerms(
                requestedCompensationRub: 0,
                desiredResolution: "other",
                problemTitle: ""
            ),
            lastModelError: nil
        )
    }

    func respondCounterpartyDispute(
        token: String,
        threadID: String,
        disputeID: String,
        responseDescription: String,
        acceptableRefundPercent: Int,
        desiredResolution: String
    ) async throws -> DisputeState {
        DisputeState(
            id: disputeID,
            threadID: threadID,
            status: "model_thinking",
            initiatorUserID: "mock-1",
            counterpartyUserID: "dev",
            initiatorPartyRole: "customer",
            viewerSide: "counterparty",
            viewerPartyRole: "performer",
            openedByDisplayName: "Тестовый пользователь",
            counterpartyDeadlineAt: nil,
            activeRound: 1,
            isModelThinking: true,
            resolutionSummary: nil,
            selectedOptionID: nil,
            moderatorRequired: false,
            questions: [],
            requiredAnswerPartyRoles: [],
            options: [],
            votes: [:],
            myVoteOptionID: nil,
            initiatorTerms: DisputeInitiatorTerms(
                requestedCompensationRub: 0,
                desiredResolution: desiredResolution,
                problemTitle: ""
            ),
            lastModelError: nil
        )
    }

    func selectDisputeOption(
        token: String,
        threadID: String,
        disputeID: String,
        optionID: String
    ) async throws -> DisputeState {
        DisputeState(
            id: disputeID,
            threadID: threadID,
            status: "resolved",
            initiatorUserID: "mock-1",
            counterpartyUserID: "dev",
            initiatorPartyRole: "customer",
            viewerSide: "counterparty",
            viewerPartyRole: "performer",
            openedByDisplayName: "Тестовый пользователь",
            counterpartyDeadlineAt: nil,
            activeRound: 1,
            isModelThinking: false,
            resolutionSummary: "Тестовое закрытие по выбранному варианту",
            selectedOptionID: optionID,
            moderatorRequired: false,
            questions: [],
            requiredAnswerPartyRoles: [],
            options: [],
            votes: ["customer": optionID, "performer": optionID],
            myVoteOptionID: optionID,
            initiatorTerms: DisputeInitiatorTerms(
                requestedCompensationRub: 0,
                desiredResolution: "other",
                problemTitle: ""
            ),
            lastModelError: nil
        )
    }

    func ensureSupportThread(token: String) async throws -> String {
        "mock-support-thread"
    }

    func fetchSupportMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        [
            ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "support-1", text: "Здравствуйте! Чем можем помочь?", createdAt: Date().addingTimeInterval(-180)),
            ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "dev", text: "Нужна помощь с заказом", createdAt: Date().addingTimeInterval(-60)),
        ]
    }

    func sendSupportMessage(token: String, threadID: String, text: String) async throws -> ChatMessage {
        ChatMessage(id: UUID().uuidString, threadID: threadID, senderID: "dev", text: text, createdAt: .now)
    }

    func fetchReportReasonOptions(token: String) async throws -> [ReportReasonOption] {
        [
            ReportReasonOption(
                code: "abuse_insults",
                title: "Оскорбления и абьюз",
                description: "Грубость, унижения, токсичное общение.",
                allowedTargetTypes: ["message", "user"]
            ),
            ReportReasonOption(
                code: "spam",
                title: "Спам",
                description: "Навязчивые или повторяющиеся сообщения.",
                allowedTargetTypes: ["message", "user", "task", "announcement"]
            ),
            ReportReasonOption(
                code: "other",
                title: "Другое",
                description: "Опишите проблему своими словами.",
                allowedTargetTypes: ["message", "user", "task", "announcement"]
            ),
        ]
    }

    func submitReport(
        token: String,
        targetType: String,
        targetID: String,
        reasonCode: String,
        reasonText: String?
    ) async throws {
    }
}
