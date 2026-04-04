import Foundation

enum Endpoints {
    static let baseURL: URL = AppConfig.apiBaseURL
}

enum HTTPMethod: String {
    case GET, POST, PATCH, DELETE
}

enum APIEndpoint {
    case register
    case login
    case me
    case usersMe
    case updateMyProfile
    case myReviews(limit: Int, offset: Int, role: String?)
    case announcementReviewContext(announcementID: String)
    case submitAnnouncementReview(announcementID: String)
    case registerDevice
    case deleteCurrentDevice

    // Announcements
    case createAnnouncement
    case myAnnouncements
    case publicAnnouncements
    case announcement(id: String)

    case uploadAnnouncementMedia(id: String)
    case appealAnnouncement(id: String)
    case submitOffer(announcementID: String)
    case announcementOffers(announcementID: String)
    case acceptOffer(announcementID: String, offerID: String)
    case rejectOffer(announcementID: String, offerID: String)
    case updateExecutionStage(announcementID: String)
    case announcementRoute(announcementID: String)
    case announcementRouteContext(announcementID: String)
    case myCurrentRoute
    case myCurrentRouteContext
    case routeBuild

    case archiveAnnouncement(id: String)
    case deleteAnnouncement(id: String)

    case chats
    case chatMessages(threadID: String, limit: Int, before: String?)
    case sendChatMessage(threadID: String)

    var path: String {
        switch self {
        case .register: return "auth/register"
        case .login: return "auth/login"
        case .me: return "me"
        case .usersMe: return "users/me"
        case .updateMyProfile: return "users/me/profile"
        case .myReviews: return "users/me/reviews"
        case .announcementReviewContext(let announcementID): return "announcements/\(announcementID)/review-context"
        case .submitAnnouncementReview(let announcementID): return "announcements/\(announcementID)/review"
        case .registerDevice: return "devices/register"
        case .deleteCurrentDevice: return "devices/me"

        case .createAnnouncement: return "announcements"
        case .myAnnouncements: return "announcements/me"
        case .publicAnnouncements: return "announcements/public"
        case .announcement(let id): return "announcements/\(id)"

        case .uploadAnnouncementMedia(let id): return "announcements/\(id)/media"
        case .appealAnnouncement(let id): return "announcements/\(id)/appeal"
        case .submitOffer(let announcementID): return "announcements/\(announcementID)/offers"
        case .announcementOffers(let announcementID): return "announcements/\(announcementID)/offers"
        case .acceptOffer(let announcementID, let offerID): return "announcements/\(announcementID)/offers/\(offerID)/accept"
        case .rejectOffer(let announcementID, let offerID): return "announcements/\(announcementID)/offers/\(offerID)/reject"
        case .updateExecutionStage(let announcementID): return "announcements/\(announcementID)/execution-stage"
        case .announcementRoute(let announcementID): return "announcements/\(announcementID)/route"
        case .announcementRouteContext(let announcementID): return "announcements/\(announcementID)/route/context"
        case .myCurrentRoute: return "routes/me/current"
        case .myCurrentRouteContext: return "routes/me/current/context"
        case .routeBuild: return "route/build"

        case .archiveAnnouncement(let id): return "announcements/\(id)/archive"
        case .deleteAnnouncement(let id): return "announcements/\(id)"
        case .chats: return "chats"
        case .chatMessages(let threadID, _, _): return "chats/\(threadID)/messages"
        case .sendChatMessage(let threadID): return "chats/\(threadID)/messages"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .login, .createAnnouncement, .registerDevice, .submitOffer, .acceptOffer, .rejectOffer, .updateExecutionStage, .sendChatMessage, .routeBuild, .submitAnnouncementReview:
            return .POST
        case .me, .usersMe, .myReviews, .announcementReviewContext, .myAnnouncements, .publicAnnouncements, .announcement, .announcementOffers, .announcementRoute, .announcementRouteContext, .myCurrentRoute, .myCurrentRouteContext, .chats, .chatMessages:
            return .GET
        case .uploadAnnouncementMedia, .appealAnnouncement:
            return .POST
        case .updateMyProfile, .archiveAnnouncement:
            return .PATCH
        case .deleteCurrentDevice, .deleteAnnouncement:
            return .DELETE
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .myReviews(let limit, let offset, let role):
            var items = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if let role, !role.isEmpty {
                items.append(URLQueryItem(name: "role", value: role))
            }
            return items
        case .chatMessages(_, let limit, let before):
            var items = [URLQueryItem(name: "limit", value: String(limit))]
            if let before, !before.isEmpty {
                items.append(URLQueryItem(name: "before", value: before))
            }
            return items
        default:
            return []
        }
    }

    var url: URL {
        let baseURL = Endpoints.baseURL.appendingPathComponent(path)
        guard !queryItems.isEmpty,
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else {
            return baseURL
        }

        components.queryItems = queryItems
        return components.url ?? baseURL
    }
}
