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
            announcementTitle: announcementTitle
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

    var domain: ChatThreadPreview {
        ChatThreadPreview(
            threadID: thread_id,
            kind: kind,
            partnerID: partner_id,
            partnerName: normalizedChatText(partner_display_name) ?? "Собеседник",
            partnerAvatarURL: partner_avatar_url.flatMap { AppURLResolver.resolveAPIURL(from: $0) },
            lastMessageText: normalizedChatText(last_message_text) ?? "Чат открыт",
            lastMessageAt: ProfileDateParser.parse(last_message_at),
            unreadCount: unread_count,
            announcementID: announcement_id,
            announcementTitle: normalizedChatText(announcement_title)
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

private func normalizedChatText(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
