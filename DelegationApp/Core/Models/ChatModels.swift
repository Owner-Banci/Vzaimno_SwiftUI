import Foundation

struct ChatThreadPreview: Identifiable, Equatable, Hashable {
    let threadID: String
    let kind: String
    let partnerID: String?
    let partnerName: String
    let partnerAvatarURL: URL?
    let lastMessageText: String
    let lastMessageAt: Date?
    let unreadCount: Int
    let announcementID: String?
    let announcementTitle: String?
    let isPinned: Bool

    var id: String { threadID }

    var partnerInitials: String {
        let parts = partnerName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first.map(String.init) }

        return parts.isEmpty ? "?" : parts.joined().uppercased()
    }

    var formattedTime: String {
        guard let lastMessageAt else { return "" }

        if Calendar.current.isDateInToday(lastMessageAt) {
            return lastMessageAt.formatted(date: .omitted, time: .shortened)
        }

        if Calendar.current.isDateInYesterday(lastMessageAt) {
            return "Вчера"
        }

        return lastMessageAt.formatted(.dateTime.day().month(.abbreviated))
    }

    static func acceptedOfferThread(
        threadID: String,
        performer: OfferPerformer?,
        announcementID: String,
        announcementTitle: String
    ) -> ChatThreadPreview {
        ChatThreadPreview(
            threadID: threadID,
            kind: "offer",
            partnerID: performer?.userID,
            partnerName: performer?.displayName ?? "Собеседник",
            partnerAvatarURL: performer?.avatarURL,
            lastMessageText: "Чат открыт",
            lastMessageAt: nil,
            unreadCount: 0,
            announcementID: announcementID,
            announcementTitle: announcementTitle,
            isPinned: false
        )
    }
}

struct ChatMessage: Identifiable, Equatable, Hashable {
    let id: String
    let threadID: String
    let senderID: String
    let text: String
    let createdAt: Date

    var isSystem: Bool {
        senderID == "system"
    }
}

struct ChatThreadPreviewDTO: Codable {
    let thread_id: String
    let kind: String
    let partner_id: String?
    let partner_display_name: String
    let partner_avatar_url: String?
    let last_message_text: String?
    let last_message_at: String?
    let unread_count: Int
    let announcement_id: String?
    let announcement_title: String?
    let is_pinned: Bool?

    var domain: ChatThreadPreview {
        let resolvedPartnerName = kind == "support"
            ? "Поддержка Vzaimno"
            : (normalizedChatText(partner_display_name) ?? "Собеседник")
        return ChatThreadPreview(
            threadID: thread_id,
            kind: kind,
            partnerID: partner_id,
            partnerName: resolvedPartnerName,
            partnerAvatarURL: partner_avatar_url.flatMap { AppURLResolver.resolveAPIURL(from: $0) },
            lastMessageText: normalizedChatText(last_message_text)
                ?? (kind == "support" ? "Чат с поддержкой открыт" : "Чат открыт"),
            lastMessageAt: ProfileDateParser.parse(last_message_at),
            unreadCount: unread_count,
            announcementID: announcement_id,
            announcementTitle: normalizedChatText(announcement_title),
            isPinned: is_pinned ?? (kind == "support")
        )
    }
}

struct ChatMessageDTO: Codable {
    let id: String
    let thread_id: String
    let sender_id: String
    let text: String
    let created_at: String

    var domain: ChatMessage {
        ChatMessage(
            id: id,
            threadID: thread_id,
            senderID: sender_id,
            text: text,
            createdAt: ProfileDateParser.parse(created_at) ?? .now
        )
    }
}

struct SendChatMessageRequestDTO: Codable {
    let text: String
}

struct OpenDisputeRequestDTO: Codable {
    let problem_title: String
    let problem_description: String
    let requested_compensation_rub: Int
    let desired_resolution: String
}

struct CounterpartyDisputeResponseRequestDTO: Codable {
    let response_description: String
    let acceptable_refund_percent: Int
    let desired_resolution: String
}

struct SelectDisputeOptionRequestDTO: Codable {
    let option_id: String
}

struct DisputeQuestion: Identifiable, Equatable, Hashable {
    let id: String
    let addressedParty: String
    let text: String
}

struct DisputeSettlementOption: Identifiable, Equatable, Hashable {
    let id: String
    let lean: String
    let title: String
    let description: String
    let customerAction: String
    let performerAction: String
    let compensationRub: Int?
    let refundPercent: Int?
    let resolutionKind: String

    var compactTitle: String {
        if let compensationRub {
            return "\(title) • \(compensationRub.formatted(.number.grouping(.automatic))) ₽"
        }
        return title
    }
}

struct DisputeInitiatorTerms: Equatable, Hashable {
    let requestedCompensationRub: Int
    let desiredResolution: String
    let problemTitle: String
}

struct DisputeState: Equatable, Hashable {
    let id: String
    let threadID: String
    let status: String
    let initiatorUserID: String
    let counterpartyUserID: String
    let initiatorPartyRole: String
    let viewerSide: String
    let viewerPartyRole: String?
    let openedByDisplayName: String
    let counterpartyDeadlineAt: Date?
    let activeRound: Int
    let isModelThinking: Bool
    let resolutionSummary: String?
    let selectedOptionID: String?
    let moderatorRequired: Bool
    let questions: [DisputeQuestion]
    let requiredAnswerPartyRoles: [String]
    let options: [DisputeSettlementOption]
    let votes: [String: String]
    let myVoteOptionID: String?
    let initiatorTerms: DisputeInitiatorTerms
    let lastModelError: String?

    var isWaitingCounterparty: Bool {
        status == "open_waiting_counterparty"
    }

    var isWaitingClarificationAnswers: Bool {
        status == "waiting_clarification_answers"
    }

    var isWaitingRound1Votes: Bool {
        status == "waiting_round_1_votes"
    }

    var isWaitingRound2Votes: Bool {
        status == "waiting_round_2_votes"
    }

    var canOpenNewDispute: Bool {
        !moderatorRequired
            && !isWaitingCounterparty
            && !isModelThinking
            && !isWaitingClarificationAnswers
            && !isWaitingRound1Votes
            && !isWaitingRound2Votes
    }
}

struct DisputeQuestionDTO: Codable {
    let id: String
    let addressed_party: String
    let text: String

    var domain: DisputeQuestion {
        DisputeQuestion(
            id: id,
            addressedParty: addressed_party,
            text: text
        )
    }
}

struct DisputeSettlementOptionDTO: Codable {
    let id: String
    let lean: String
    let title: String
    let description: String
    let customer_action: String
    let performer_action: String
    let compensation_rub: Int?
    let refund_percent: Int?
    let resolution_kind: String

    var domain: DisputeSettlementOption {
        DisputeSettlementOption(
            id: id,
            lean: lean,
            title: title,
            description: description,
            customerAction: customer_action,
            performerAction: performer_action,
            compensationRub: compensation_rub,
            refundPercent: refund_percent,
            resolutionKind: resolution_kind
        )
    }
}

struct DisputeInitiatorTermsDTO: Codable {
    let requested_compensation_rub: Int?
    let desired_resolution: String?
    let problem_title: String?

    var domain: DisputeInitiatorTerms {
        DisputeInitiatorTerms(
            requestedCompensationRub: requested_compensation_rub ?? 0,
            desiredResolution: normalizedChatText(desired_resolution) ?? "other",
            problemTitle: normalizedChatText(problem_title) ?? ""
        )
    }
}

struct DisputeStateDTO: Codable {
    let id: String
    let thread_id: String
    let status: String
    let initiator_user_id: String
    let counterparty_user_id: String
    let initiator_party_role: String
    let viewer_side: String
    let viewer_party_role: String?
    let opened_by_display_name: String
    let counterparty_deadline_at: String?
    let active_round: Int?
    let is_model_thinking: Bool?
    let resolution_summary: String?
    let selected_option_id: String?
    let moderator_required: Bool?
    let questions: [DisputeQuestionDTO]?
    let required_answer_party_roles: [String]?
    let options: [DisputeSettlementOptionDTO]?
    let votes: [String: String]?
    let my_vote_option_id: String?
    let initiator_terms: DisputeInitiatorTermsDTO?
    let last_model_error: String?

    var domain: DisputeState {
        DisputeState(
            id: id,
            threadID: thread_id,
            status: status,
            initiatorUserID: initiator_user_id,
            counterpartyUserID: counterparty_user_id,
            initiatorPartyRole: initiator_party_role,
            viewerSide: viewer_side,
            viewerPartyRole: normalizedChatText(viewer_party_role),
            openedByDisplayName: normalizedChatText(opened_by_display_name) ?? "Система",
            counterpartyDeadlineAt: ProfileDateParser.parse(counterparty_deadline_at),
            activeRound: max(1, active_round ?? 1),
            isModelThinking: is_model_thinking ?? false,
            resolutionSummary: normalizedChatText(resolution_summary),
            selectedOptionID: normalizedChatText(selected_option_id),
            moderatorRequired: moderator_required ?? false,
            questions: (questions ?? []).map(\.domain),
            requiredAnswerPartyRoles: required_answer_party_roles ?? [],
            options: (options ?? []).map(\.domain),
            votes: votes ?? [:],
            myVoteOptionID: normalizedChatText(my_vote_option_id),
            initiatorTerms: initiator_terms?.domain ?? DisputeInitiatorTerms(
                requestedCompensationRub: 0,
                desiredResolution: "other",
                problemTitle: ""
            ),
            lastModelError: normalizedChatText(last_model_error)
        )
    }
}

struct SupportThreadDTO: Codable {
    let thread_id: String
}

struct ChatRealtimeCapabilities: Equatable, Hashable {
    let chatWebSocketEnabled: Bool
    let websocketPath: String
}

struct ChatRealtimeCapabilitiesDTO: Codable {
    let chat_websocket_enabled: Bool?
    let websocket_path: String?

    var domain: ChatRealtimeCapabilities {
        ChatRealtimeCapabilities(
            chatWebSocketEnabled: chat_websocket_enabled ?? false,
            websocketPath: normalizedChatText(websocket_path) ?? "/ws/chats/{thread_id}"
        )
    }
}

struct ReportReasonOption: Identifiable, Equatable, Hashable {
    let code: String
    let title: String
    let description: String
    let allowedTargetTypes: [String]

    var id: String { code }

    func supports(targetType: String) -> Bool {
        allowedTargetTypes.contains(targetType)
    }
}

struct ReportReasonOptionDTO: Codable {
    let code: String
    let title: String
    let description: String
    let allowed_target_types: [String]

    var domain: ReportReasonOption {
        ReportReasonOption(
            code: code,
            title: title,
            description: description,
            allowedTargetTypes: allowed_target_types
        )
    }
}

struct ReportSubmissionRequestDTO: Codable {
    let target_type: String
    let target_id: String
    let reason_code: String
    let reason_text: String?
}

struct ReportDTO: Codable {
    let id: String
}

private func normalizedChatText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
