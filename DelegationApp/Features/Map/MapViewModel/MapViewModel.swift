//
// MapScreen.swift
// iCuno test
//
// Created by maftuna murtazaева on 07.11.2025.
//

import SwiftUI
import YandexMapsMobile
import Foundation



// MARK: - Холст карты

/// Вью, которая отвечает ТОЛЬКО за "холст карты":
/// она выбирает — показать реальную карту или заглушку.
///
/// Важно: логика поиска/маршрутов/заданий работает независимо от этого выбора,
/// потому что она живёт в `MapViewModel` и сервисах.
/// Обёртка над картой/заглушкой.
/// Она не знает ни про фильтры, ни про поиск — только про то, ЧТО рисовать.
struct MapCanvasView: View {

    /// Точка, на которую должна быть центрирована карта.
    @Binding var centerPoint: YMKPoint?

    /// Режим отображения.
    let mode: MapDisplayMode

    var body: some View {
        Group {
            switch mode {
            case .real:
                YandexMapView(centerPoint: $centerPoint)
//                    .ignoresSafeArea(edges: .bottom)

            case .placeholder:
                Rectangle()
                    .fill(Theme.ColorToken.milk)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.ColorToken.textSecondary)
                            Text("Map placeholder")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.ColorToken.textSecondary)
                        }
                    )
//                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

/// Простая заглушка вместо карты.
struct MapPlaceholderView: View {
    var body: some View {
        Rectangle()
            .fill(Theme.ColorToken.milk)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.ColorToken.textSecondary)
                    Text("Map placeholder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.ColorToken.textSecondary)
                }
            )
    }
}

// MARK: - ViewModel карты

/// ViewModel для экрана карты: фильтры, задачи, поиск адреса, центр карты.
final class MapViewModel: ObservableObject {

    // MARK: - Фильтры (чипы)

    @Published var chips: [String] = [
        "Купить", "Доставить", "Забрать",
        "Помочь", "Перенести", "Другое"
    ]

    @Published var selected: Set<String> = []

    // MARK: - Задачи рядом

    @Published var tasks: [TaskItem] = []

    // MARK: - Поиск и карта

    /// Текст в поле поиска адреса.
    @Published var searchText: String = ""

    /// Текущая точка, на которую центрируется карта.
    @Published var centerPoint: YMKPoint?

    /// Сообщение об ошибке (например, "Ничего не найдено").
    @Published var errorMessage: String?

    private let service: TaskService
    private let searchService: AddressSearchService

    init(
        service: TaskService,
        searchService: AddressSearchService = AddressSearchService()
    ) {
        self.service = service
        self.searchService = searchService

        // Загружаем задачи поблизости (как и раньше).
        self.tasks = service.loadNearbyTasks()

        // Стартовая точка карты — Москва (можешь поменять на Самарканд).
        self.centerPoint = YMKPoint(
            latitude: 55.751244,
            longitude: 37.618423
        )
    }

    // MARK: - Логика фильтров

    func toggle(_ chip: String) {
        if selected.contains(chip) {
            selected.remove(chip)
        } else {
            selected.insert(chip)
        }
    }

    // MARK: - Поиск адреса

    /// Выполнить поиск по адресу и сдвинуть карту.
    ///
    /// Важно: этот код работает даже тогда, когда на UI показывается заглушка.
    /// Просто не будет рендериться сама карта, но `centerPoint` обновится,
    /// и при включении настоящей карты ты сразу увидишь правильную точку.
    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            // Пустой запрос — просто сбрасываем ошибку.
            errorMessage = nil
            return
        }

        searchService.searchAddress(query) { [weak self] point in
            DispatchQueue.main.async {
                guard let self else { return }

                if let point {
                    // Успех: центрируем карту в этой точке.
                    self.centerPoint = point
                    self.errorMessage = nil
                } else {
                    // Ничего не нашли.
                    self.errorMessage = "Ничего не найдено"
                }
            }
        }
    }
}
