//
//  AdModels.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 24.11.2025.
//

//
//  AdModels.swift
//  iCuno test
//
//  Создано для экрана объявлений.
//

import Foundation

/// Модель объявления. Пока используется только для мок-данных
/// на экране "Мои объявления".
struct AdItem: Identifiable {
    let id: UUID = .init()
    let title: String
    let priceDescription: String
    let isExpired: Bool
    let views: Int
    let responses: Int
    let favorites: Int
}
