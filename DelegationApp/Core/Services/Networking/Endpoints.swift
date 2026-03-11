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
    case myReviews(limit: Int, offset: Int)
    case registerDevice
    case deleteCurrentDevice

    // Announcements
    case createAnnouncement
    case myAnnouncements
    case publicAnnouncements

    case uploadAnnouncementMedia(id: String)
    case appealAnnouncement(id: String)
    case submitOffer(announcementID: String)
    case announcementOffers(announcementID: String)
    case acceptOffer(announcementID: String, offerID: String)
    case rejectOffer(announcementID: String, offerID: String)
    case announcementRoute(announcementID: String)
    case myCurrentRoute

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
        case .registerDevice: return "devices/register"
        case .deleteCurrentDevice: return "devices/me"

        case .createAnnouncement: return "announcements"
        case .myAnnouncements: return "announcements/me"
        case .publicAnnouncements: return "announcements/public"

        case .uploadAnnouncementMedia(let id): return "announcements/\(id)/media"
        case .appealAnnouncement(let id): return "announcements/\(id)/appeal"
        case .submitOffer(let announcementID): return "announcements/\(announcementID)/offers"
        case .announcementOffers(let announcementID): return "announcements/\(announcementID)/offers"
        case .acceptOffer(let announcementID, let offerID): return "announcements/\(announcementID)/offers/\(offerID)/accept"
        case .rejectOffer(let announcementID, let offerID): return "announcements/\(announcementID)/offers/\(offerID)/reject"
        case .announcementRoute(let announcementID): return "announcements/\(announcementID)/route"
        case .myCurrentRoute: return "routes/me/current"

        case .archiveAnnouncement(let id): return "announcements/\(id)/archive"
        case .deleteAnnouncement(let id): return "announcements/\(id)"
        case .chats: return "chats"
        case .chatMessages(let threadID, _, _): return "chats/\(threadID)/messages"
        case .sendChatMessage(let threadID): return "chats/\(threadID)/messages"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .login, .createAnnouncement, .registerDevice, .submitOffer, .acceptOffer, .rejectOffer, .sendChatMessage:
            return .POST
        case .me, .usersMe, .myReviews, .myAnnouncements, .publicAnnouncements, .announcementOffers, .announcementRoute, .myCurrentRoute, .chats, .chatMessages:
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
        case .myReviews(let limit, let offset):
            return [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
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
