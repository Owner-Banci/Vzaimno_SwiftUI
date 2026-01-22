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

    // Без ведущего "/" — безопасно для appendingPathComponent
    var path: String {
        switch self {
        case .register: return "auth/register"
        case .login:    return "auth/login"
        case .me:       return "me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .login: return .POST
        case .me: return .GET
        }
    }

    var url: URL {
        Endpoints.baseURL.appendingPathComponent(path)
    }
}
