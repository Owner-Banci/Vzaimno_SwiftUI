//
//  AppConfig.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 22.01.2026.
//

import Foundation

enum AppConfig {

    // =========================================
    // DEV-ПЕРЕКЛЮЧАТЕЛЬ АВТОРИЗАЦИИ
    // =========================================
    // Хочешь разрабатывать приложение БЕЗ регистрации/логина?
    // Просто поставь false, и приложение будет сразу пускать внутрь.
    //
    // Когда будешь полноценно тестировать — верни true.
    static let authEnabled: Bool = {
        #if DEBUG
        return true  // <-- МЕНЯЕШЬ ТУТ: false = без авторизации
        #else
        return true
        #endif
    }()

    // =========================================
    // BASE URL ДЛЯ API
    // =========================================
    // По умолчанию используем удаленный production backend.
    // При необходимости можно переопределить через Info.plist ключ API_BASE_URL.
    static let apiBaseURL: URL = {
        if let s = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !s.isEmpty,
           let url = URL(string: s) {
            return url
        }

        let fallback = "https://api.vzaimno.net"

        guard let url = URL(string: fallback) else {
            preconditionFailure("Invalid API base URL fallback: \(fallback)")
        }
        return url
    }()

    static let webSocketBaseURL: URL = {
        guard var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false) else {
            return apiBaseURL
        }

        if components.scheme == "https" {
            components.scheme = "wss"
        } else {
            components.scheme = "ws"
        }

        return components.url ?? apiBaseURL
    }()
}
