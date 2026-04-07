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

struct SupportThreadDTO: Codable {
    let thread_id: String
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
