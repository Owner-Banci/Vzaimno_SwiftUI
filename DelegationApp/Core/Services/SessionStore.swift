import Foundation
import Security

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var me: MeResponse?
    @Published var errorText: String?
    @Published private(set) var isRestoring: Bool = true
    @Published private(set) var isBusy: Bool = false

    private let auth: AuthService
    private let deviceService: DeviceService
    private let keychainKey = "icuno.jwt.access_token"

    init(auth: AuthService, deviceService: DeviceService) {
        self.auth = auth
        self.deviceService = deviceService

        if !AppConfig.authEnabled {
            self.token = "DEV_TOKEN"
            self.me = MeResponse(id: "dev", email: "dev@local", role: "user")
            self.isRestoring = false
            return
        }

        self.token = Keychain.readString(key: keychainKey)
        Task { await restoreSession() }
    }

    var isAuthorized: Bool { token != nil }

    func restoreSession() async {
        isRestoring = false

        guard token != nil else { return }

        Task { [weak self] in
            guard let self else { return }
            await self.validateTokenInBackground()
        }
    }

    func register(email: String, password: String) async {
        await runAuthFlow(email: email, password: password) {
            let response = try await auth.register(email: email, password: password)
            try await authorize(with: response.access_token)
        }
    }

    func login(email: String, password: String) async {
        await runAuthFlow(email: email, password: password) {
            let response = try await auth.login(email: email, password: password)
            try await authorize(with: response.access_token)
        }
    }

    func loadMe() async throws {
        guard let token else {
            throw NSError(
                domain: "SessionStore",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Нет токена"]
            )
        }

        let profile = try await auth.me(token: token)
        self.me = profile
    }

    func logout() async {
        let currentToken = token
        errorText = nil
        isBusy = true

        if AppConfig.authEnabled, let currentToken {
            do {
                try await deviceService.unregisterCurrentDevice(token: currentToken)
            } catch {
                if !error.isUnauthorizedResponse {
                    errorText = "Сессия завершена, но устройство не удалось отвязать: \(error.localizedDescription)"
                }
            }
        }

        clearSession()
        isBusy = false
    }

    private func validateTokenInBackground() async {
        guard token != nil else { return }

        do {
            try await withTimeout(seconds: 5) {
                try await self.loadMe()
            }
            await registerDeviceIfPossible()
        } catch is TimeoutError {
            self.errorText = "Не удалось проверить сессию (таймаут). Проверь API Base URL."
        } catch {
            clearSession()
            self.errorText = error.localizedDescription
        }
    }

    private func runAuthFlow(
        email: String,
        password: String,
        action: () async throws -> Void
    ) async {
        errorText = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorText = "Заполни email и пароль"
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            try await action()
        } catch {
            clearSession()
            errorText = error.localizedDescription
        }
    }

    private func authorize(with accessToken: String) async throws {
        setTokenAndStore(accessToken)

        do {
            try await loadMe()
            await registerDeviceIfPossible()
        } catch {
            clearSession()
            throw error
        }
    }

    private func registerDeviceIfPossible() async {
        guard AppConfig.authEnabled, let token else { return }

        do {
            try await deviceService.registerCurrentDevice(token: token)
        } catch {
            print("Device registration failed: \(error.localizedDescription)")
        }
    }

    private func setTokenAndStore(_ value: String) {
        token = value
        Keychain.saveString(value, key: keychainKey)
    }

    private func clearSession() {
        token = nil
        me = nil
        Keychain.delete(key: keychainKey)
        URLCache.shared.removeAllCachedResponses()
    }

    private struct TimeoutError: LocalizedError {
        var errorDescription: String? { "Таймаут" }
    }

    private func withTimeout<T>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask { [seconds] in
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw Self.TimeoutError()
            }

            guard let result = try await group.next() else {
                group.cancelAll()
                throw TimeoutError()
            }

            group.cancelAll()
            return result
        }
    }
}

enum Keychain {
    static func saveString(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }

        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func readString(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
