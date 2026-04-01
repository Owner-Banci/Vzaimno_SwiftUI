import Foundation
import Security

private enum SessionProfileCache {
    private static let meKey = "icuno.session.me"

    static func save(_ me: MeResponse?) {
        let defaults = UserDefaults.standard

        guard let me else {
            defaults.removeObject(forKey: meKey)
            return
        }

        guard let data = try? JSONEncoder().encode(me) else { return }
        defaults.set(data, forKey: meKey)
    }

    static func load() -> MeResponse? {
        guard let data = UserDefaults.standard.data(forKey: meKey) else { return nil }
        return try? JSONDecoder().decode(MeResponse.self, from: data)
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var me: MeResponse?
    @Published var errorText: String?
    @Published private(set) var connectivityBannerText: String?
    @Published private(set) var isOffline: Bool = false
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
        self.me = self.token == nil ? nil : SessionProfileCache.load()
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
        SessionProfileCache.save(profile)
        clearConnectivityState()
    }

    func logout() async {
        let currentToken = token
        errorText = nil
        clearConnectivityState()
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
            applyOfflineState(message: "Нет соединения с сервером. Работаем офлайн.")
        } catch {
            if error.invalidatesSession {
                clearSession()
                self.errorText = "Сессия истекла или была отозвана. Войдите снова."
            } else {
                applyOfflineState(
                    message: error.isConnectivityError
                        ? "Нет соединения с сервером. Работаем офлайн."
                        : "Сервер временно недоступен. Сессия сохранена."
                )
            }
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
            errorText = error.localizedDescription
        }
    }

    private func authorize(with accessToken: String) async throws {
        setTokenAndStore(accessToken)
        errorText = nil

        do {
            try await loadMe()
            await registerDeviceIfPossible()
        } catch {
            if error.invalidatesSession {
                clearSession()
                throw error
            }

            applyOfflineState(
                message: error.isConnectivityError
                    ? "Вход выполнен, но сервер сейчас недоступен. Продолжаем с локальной сессией."
                    : "Вход выполнен, но профиль не удалось обновить. Продолжаем с локальной сессией."
            )
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

    private func applyOfflineState(message: String) {
        isOffline = true
        connectivityBannerText = message
    }

    private func clearConnectivityState() {
        isOffline = false
        connectivityBannerText = nil
    }

    private func clearSession() {
        token = nil
        me = nil
        clearConnectivityState()
        Keychain.delete(key: keychainKey)
        SessionProfileCache.save(nil)
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
