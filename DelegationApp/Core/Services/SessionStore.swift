import Foundation
import Security

@MainActor
final class SessionStore: ObservableObject {

    // MARK: - Published state
    @Published private(set) var token: String?
    @Published private(set) var me: MeResponse?
    @Published var errorText: String?
    @Published private(set) var isRestoring: Bool = true
    @Published private(set) var isBusy: Bool = false

    // MARK: - Private
    private let auth: AuthService
    private let keychainKey = "icuno.jwt.access_token"

    // MARK: - Init
    init(auth: AuthService) {
        self.auth = auth

        // =========================================
        // DEV: если авторизация выключена —
        // сразу пускаем внутрь и НИЧЕГО не проверяем
        // =========================================
        if !AppConfig.authEnabled {
            self.token = "DEV_TOKEN"
            self.me = MeResponse(id: "dev", email: "dev@local", role: "user")
            self.isRestoring = false
            return
        }

        // Читаем токен при старте
        self.token = Keychain.readString(key: keychainKey)

        // При запуске — пробуем восстановить (НО без “вечной” блокировки UI)
        Task { await self.restoreSession() }

    }

    // MARK: - Computed
    var isAuthorized: Bool { token != nil }

    // MARK: - Public actions

    /// Восстановление сессии при старте приложения.
    /// ВАЖНО: UI не должен “висеть” пока сеть думает.
    func restoreSession() async {
        // Сразу снимаем экран “Проверяем сессию…”
        isRestoring = false

        guard token != nil else { return }

        // Проверку токена делаем отдельной задачей (не блокируем RootView)
        Task { [weak self] in
            guard let self else { return }
            await self.validateTokenInBackground()
        }
    }

    func register(email: String, password: String) async {
        await runAuthFlow(email: email, password: password) {
            let t = try await auth.register(email: email, password: password)
            setTokenAndStore(t.access_token)
            try await loadMe()
        }
    }

    func login(email: String, password: String) async {
        await runAuthFlow(email: email, password: password) {
            let t = try await auth.login(email: email, password: password)
            setTokenAndStore(t.access_token)
            try await loadMe()
        }
    }

    func loadMe() async throws {
        guard let token else {
            throw NSError(domain: "SessionStore", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Нет токена"])
        }
        let profile = try await auth.me(token: token)
        self.me = profile
    }

    func logout() {
        clearSession()
    }

    // MARK: - Background validation

    private func validateTokenInBackground() async {
        guard token != nil else { return }

        do {
            // Если сервер недоступен (например, baseURL не тот) — не выкидываем сразу пользователя,
            // а просто показываем ошибку, чтобы не было бесконечной загрузки.
//            try await withTimeout(seconds: 5) {
//                try await loadMe()
//            }
            try await withTimeout(seconds: 5) {
                try await self.loadMe()
            }

        } catch is TimeoutError {
            self.errorText = "Не удалось проверить сессию (таймаут). Проверь API Base URL."
        } catch {
            // Если токен реально невалиден/просрочен — чистим
            clearSession()
            self.errorText = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func runAuthFlow(
        email: String,
        password: String,
        action: () async throws -> Void
    ) async {
        errorText = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass  = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPass.isEmpty else {
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

    private func setTokenAndStore(_ value: String) {
        token = value
        Keychain.saveString(value, key: keychainKey)
    }

    private func clearSession() {
        token = nil
        me = nil
        Keychain.delete(key: keychainKey)
    }

    // MARK: - Timeout helper

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
//            group.addTask {
//                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
//                throw TimeoutError()
//            }

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

        // 1) Сначала удаляем старое значение (если было)
        delete(key: key)

        // 2) Создаём запись
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // можно добавить доступность, чтобы работало предсказуемо
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
              let str = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return str
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
