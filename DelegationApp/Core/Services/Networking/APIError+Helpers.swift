import Foundation

extension Error {
    var apiStatusCode: Int? {
        (self as? APIClient.APIError)?.statusCode
    }

    var isUnauthorizedResponse: Bool {
        apiStatusCode == 401
    }
}
