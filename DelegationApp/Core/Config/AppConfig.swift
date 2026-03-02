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
    // ВАЖНО:
    // - В симуляторе iOS часто можно ходить на 127.0.0.1 (это Mac).
    // - На РЕАЛЬНОМ iPhone 127.0.0.1 = сам iPhone, поэтому бэкенд "на маке" не доступен.
    //
    // Правильный вариант для iPhone: http://<IP_твоего_Mac_в_WiFi>:8000
    // Например: http://192.168.1.10:8000
    static let apiBaseURL: URL = {
        // Если захочешь — можешь положить API_BASE_URL в Info.plist,
        // тогда здесь подхватится автоматически (удобно для разных конфигов).
        if let s = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !s.isEmpty,
           let url = URL(string: s) {
            return url
        }

        let fallback: String
        #if targetEnvironment(simulator)
        fallback = "http://127.0.0.1:8000"
        #else
        // !!! Поменяй на IP твоего Mac (в той же сети Wi-Fi)
        fallback = "http://192.168.1.10:8000"
        #endif

        guard let url = URL(string: fallback) else {
            preconditionFailure("Invalid API base URL fallback: \(fallback)")
        }
        return url
    }()
}
