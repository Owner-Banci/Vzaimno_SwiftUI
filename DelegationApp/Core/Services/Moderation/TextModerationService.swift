//
//  TextModerationService.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 27.02.2026.
//

import Foundation

/// Быстрая локальная проверка (на устройстве), чтобы мгновенно показать UI-ошибку.
/// Это НЕ заменяет серверную модерацию (на сервере всё равно проверяем).
final class TextModerationService {
    static let shared = TextModerationService()

    enum Verdict {
        case allow
        case reject(reason: String)
        case reviewable(reason: String) // можно оспорить/унести в черновик
    }

    // Минимальные “триггеры”. Дальше ты можешь расширять списки под свои правила.
    private let hardBlockTokens: [String] = [
        "наркот", "оруж", "взрыв", "поддел", "порно"
    ]

    private let reviewTokens: [String] = [
        "продам", "куплю", "срочно", "быстро", "без документов"
    ]

    private init() {}

    func check(text: String) -> Verdict {
        let t = normalize(text)
        if t.isEmpty { return .allow }

        if containsAnyToken(in: t, tokens: hardBlockTokens) {
            return .reject(reason: "Текст похож на запрещённый контент. Измените формулировку.")
        }

        if containsAnyToken(in: t, tokens: reviewTokens) {
            return .reviewable(reason: "Текст выглядит спорным. Объявление будет сохранено как черновик (можно оспорить).")
        }

        return .allow
    }

    // MARK: - Helpers

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func containsAnyToken(in text: String, tokens: [String]) -> Bool {
        for token in tokens {
            if text.contains(token) { return true }
        }
        return false
    }
}
