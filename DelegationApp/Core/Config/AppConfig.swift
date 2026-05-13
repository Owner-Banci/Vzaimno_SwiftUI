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
    // Приоритеты:
    // 1) Environment Variable API_BASE_URL (удобно для Scheme в Xcode),
    // 2) Info.plist ключ API_BASE_URL,
    // 3) fallback по сборке.
    //
    // По умолчанию DEBUG и Release используют deployed backend.
    // Для локального backend задай API_BASE_URL через Scheme или Info.plist,
    // например http://<LAN_IP_Мака>:8000 для реального iPhone.
    static let apiBaseURL: URL = {
        if let s = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !s.isEmpty,
           let url = URL(string: s) {
            return url
        }

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
