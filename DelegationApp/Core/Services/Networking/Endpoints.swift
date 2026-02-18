import Foundation

enum Endpoints {
    static let baseURL: URL = AppConfig.apiBaseURL
}

enum HTTPMethod: String {
    case GET, POST
}

enum APIEndpoint {
    case register
    case login
    case me

    // Announcements (Ads)
    case createAnnouncement
    case myAnnouncements

    // Без ведущего "/" — безопасно для appendingPathComponent
    var path: String {
        switch self {
        case .register: return "auth/register"
        case .login:    return "auth/login"
        case .me:       return "me"
        case .createAnnouncement: return "announcements"
        case .myAnnouncements:    return "announcements/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .login, .createAnnouncement:
            return .POST
        case .me, .myAnnouncements:
            return .GET
        }
    }

    var url: URL {
        Endpoints.baseURL.appendingPathComponent(path)
    }
}
