import Foundation

struct AnnouncementModerationRoutingPlan {
    let requestStatus: String
    let shouldUploadMedia: Bool
    let shouldRunLocalTextModeration: Bool
    let moderationNote: String?

    var fastTrackMessage: String {
        if requestStatus == "active" {
            return "Объявление опубликовано"
        }
        return "Отправлено на проверку"
    }
}

@MainActor
enum AnnouncementModerationRoutingHelper {
    static func makePlan(
        for draft: CreateAdDraft,
        textModerationService: TextModerationService = .shared
    ) throws -> AnnouncementModerationRoutingPlan {
        let hasMedia = draft.hasAttachedMedia
        let verdict = textModerationService.check(text: draft.moderationTextPayload)
        switch verdict {
        case .reject(let reason):
            throw ModerationRoutingError(reason: reason)

        case .reviewable(let reason):
            return AnnouncementModerationRoutingPlan(
                requestStatus: hasMedia ? "pending_review" : "active",
                shouldUploadMedia: hasMedia,
                shouldRunLocalTextModeration: true,
                moderationNote: reason
            )

        case .allow:
            return AnnouncementModerationRoutingPlan(
                requestStatus: hasMedia ? "pending_review" : "active",
                shouldUploadMedia: hasMedia,
                shouldRunLocalTextModeration: true,
                moderationNote: nil
            )
        }
    }
}

private struct ModerationRoutingError: LocalizedError {
    let reason: String

    var errorDescription: String? {
        reason
    }
}
