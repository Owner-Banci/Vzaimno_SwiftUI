import Foundation

struct APIClient {

    struct APIError: LocalizedError {
        let statusCode: Int
        let message: String
        var errorDescription: String? {
            message.isEmpty ? "HTTP \(statusCode)" : message
        }
    }

    // FastAPI error: {"detail": "..."} или {"detail":[{"loc":...,"msg":...}]}
    private struct FastAPIError: Decodable {
        let detail: Detail

        enum Detail: Decodable {
            case string(String)
            case validation([ValidationItem])
            case unknown

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let str = try? container.decode(String.self) {
                    self = .string(str)
                    return
                }
                if let arr = try? container.decode([ValidationItem].self) {
                    self = .validation(arr)
                    return
                }
                self = .unknown
            }
        }

        struct ValidationItem: Decodable {
            let loc: [String]?
            let msg: String?
            let type: String?
        }

        var humanMessage: String {
            switch detail {
            case .string(let s):
                return s
            case .validation(let items):
                let msgs = items.compactMap { $0.msg }
                if msgs.isEmpty { return "Некорректные данные" }
                let joined = msgs.joined(separator: "\n")
                if joined.contains("value is not a valid email address") {
                    return "Неверный email. Пример: name@mail.com"
                }
                return joined
            case .unknown:
                return "Ошибка запроса"
            }
        }
    }

    // Используем свою сессию (таймауты!)
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8   // быстро падаем, а не “вечная загрузка”
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable, B: Encodable>(
        _ endpoint: APIEndpoint,
        body: B? = nil,
        token: String? = nil
    ) async throws -> T {

        var req = URLRequest(url: endpoint.url)
        req.httpMethod = endpoint.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await session.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                throw APIError(statusCode: -1, message: "Нет HTTP ответа")
            }

            if (200..<300).contains(http.statusCode) {
                return try JSONDecoder().decode(T.self, from: data)
            }

            // пробуем красиво распарсить FastAPI error
            if let apiErr = try? JSONDecoder().decode(FastAPIError.self, from: data) {
                throw APIError(statusCode: http.statusCode, message: apiErr.humanMessage)
            }

            let raw = String(data: data, encoding: .utf8) ?? ""
            throw APIError(statusCode: http.statusCode, message: raw)

        } catch let e as URLError {
            // Человеческая ошибка сети (например, если baseURL не доступен с iPhone)
            throw APIError(statusCode: -1, message: "Сеть недоступна: \(e.localizedDescription)")
        }
    }

    // Удобно для GET без body
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        token: String? = nil
    ) async throws -> T {
        try await request(endpoint, body: Optional<Int>.none, token: token)
    }
}
