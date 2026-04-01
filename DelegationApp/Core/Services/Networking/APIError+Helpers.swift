import Foundation

extension Error {
    var apiStatusCode: Int? {
        (self as? APIClient.APIError)?.statusCode
    }

    var isUnauthorizedResponse: Bool {
        apiStatusCode == 401
    }

    var isForbiddenResponse: Bool {
        apiStatusCode == 403
    }

    var invalidatesSession: Bool {
        isUnauthorizedResponse || isForbiddenResponse
    }

    var isConnectivityError: Bool {
        apiStatusCode == -1
    }
}
