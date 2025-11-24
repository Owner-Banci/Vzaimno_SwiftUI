//
//  AppRouter.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 07.11.2025.
//

// MapDisplayConfig.swift
// iCuno test

import Foundation

/// Варианты отображения карты.
enum MapDisplayMode {
    /// Реальная карта Яндекса.
    case real
    /// Заглушка.
    case placeholder
}

/// Глобальная конфигурация отображения карты.
enum MapDisplayConfig {

    /// Принудительный режим (можно задать из App для дебага).
    private(set) static var overrideMode: MapDisplayMode?

    /// Режим по умолчанию.
    static func defaultMode() -> MapDisplayMode {
        if let overrideMode { return overrideMode }

        // В превью всегда рисуем заглушку.
        if RuntimeEnvironment.isPreview {
            return .placeholder
        }

        // В обычном запуске — настоящая карта.
        return .real
    }

    /// Позволяет глобально включить/выключить карту.
    static func setOverride(_ mode: MapDisplayMode?) {
        overrideMode = mode
    }
}
