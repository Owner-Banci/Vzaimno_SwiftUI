//import SwiftUI
//
///// Вкладки приложения (сохранены ваши разделы: Карта, Маршрут, Объявления, Чаты, Профиль)
//enum AppTab: Int, CaseIterable, Identifiable {
//    case map, route, ads, chats, profile
//
//    var id: Int { rawValue }
//
//    var title: String {
//        switch self {
//        case .map:     return "Карта"
//        case .route:   return "Маршрут"
//        case .ads:     return "Объявления"
//        case .chats:   return "Чаты"
//        case .profile: return "Профиль"
//        }
//    }
//
//    /// Разные символы для «выбрано/не выбрано», чтобы выглядело как в iOS 26.
//    func iconName(selected: Bool) -> String {
//        switch self {
//        case .map:
//            return selected ? "map.fill" : "map"
//        case .route:
//            // ваш системный символ из проекта
//            return "point.topleft.down.curvedto.point.bottomright.up"
//        case .ads:
//            return selected ? "rectangle.stack.badge.plus.fill" : "rectangle.stack.badge.plus"
//        case .chats:
//            return selected ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right"
//        case .profile:
//            return selected ? "person.circle.fill" : "person.circle"
//        }
//    }
//}

import SwiftUI

/// Вкладки нижнего TabBar
enum AppTab: Int, CaseIterable, Identifiable {
    case map
    case route
    case ads
    case chats
    case profile

    var id: Int { rawValue }

    /// Текст под иконкой
    var title: String {
        switch self {
        case .map:     return "Карта"
        case .route:   return "Маршрут"
        case .ads:     return "Объявления"
        case .chats:   return "Чаты"
        case .profile: return "Профиль"
        }
    }

    /// Названия системных иконок (для выбранного/не выбранного состояния)
    func iconName(selected: Bool) -> String {
        switch self {
        case .map:
            return selected ? "map.fill" : "map"

        case .route:
            // Ваша «ветка маршрута»
            return "point.topleft.down.curvedto.point.bottomright.up"

        case .ads:
            return selected
            ? "rectangle.stack.badge.plus.fill"
            : "rectangle.stack.badge.plus"

        case .chats:
            return selected
            ? "bubble.left.and.bubble.right.fill"
            : "bubble.left.and.bubble.right"

        case .profile:
            return selected ? "person.circle.fill" : "person.circle"
        }
    }
}
