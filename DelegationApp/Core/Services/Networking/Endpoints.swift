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

    case archiveAnnouncement(id: String)
    case deleteAnnouncement(id: String)

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

        case .archiveAnnouncement(let id): return "announcements/\(id)/archive"
        case .deleteAnnouncement(let id): return "announcements/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .login, .createAnnouncement, .registerDevice:
            return .POST
        case .me, .usersMe, .myReviews, .myAnnouncements, .publicAnnouncements:
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
