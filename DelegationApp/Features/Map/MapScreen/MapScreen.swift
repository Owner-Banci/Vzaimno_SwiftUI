import SwiftUI

// MARK: - Экран "Карта"

/// Основной экран "Карта": поиск, фильтры, карта, плюс-кнопка.
struct MapScreen: View {
    @StateObject private var vm: MapViewModel
    @State private var showCreate = false

    /// Текущий режим отображения карты (реальная карта / заглушка).
    private let mapMode: MapDisplayMode

    init(
        vm: MapViewModel,
        mapMode: MapDisplayMode = MapDisplayConfig.defaultMode()
    ) {
        _vm = StateObject(wrappedValue: vm)
        self.mapMode = mapMode
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            errorLabel
            chipsRow
            mapArea
        }
        .background(Theme.ColorToken.milk)
        .navigationTitle("Карта")
    }

    // MARK: - Подвью

    /// Поисковая строка.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
//                .foregroundColor(Theme.ColorToken.textSecondary)
                .foregroundColor(Color.red)

            TextField(
                "Введите адрес",
                text: $vm.searchText,
                onCommit: vm.performSearch
            )
            .textFieldStyle(.plain)

            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.ColorToken.textSecondary)
                        .imageScale(.medium)
                }
            }

            Button(action: vm.performSearch) {
                Text("Найти")
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue)
        .softCardShadow()
    }

    /// Сообщение об ошибке поиска (если есть).
    private var errorLabel: some View {
        Group {
            if let message = vm.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
        }
    }

    /// Горизонтальный список чипов-фильтров.
    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.m) {
                ForEach(vm.chips, id: \.self) { chip in
                    FilterChip(
                        title: chip,
                        isSelected: Binding(
                            get: { vm.selected.contains(chip) },
                            set: { isOn in
                                if isOn {
                                    vm.selected.insert(chip)
                                } else {
                                    vm.selected.remove(chip)
                                }
                            }
                        )
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.green)
    }

    /// Область карты + плавающая кнопка.
    private var mapArea: some View {
        ZStack(alignment: .bottom) {
            MapCanvasView(centerPoint: $vm.centerPoint, mode: mapMode)

        }
    }
}

// MARK: - Preview



// MapCanvasView.swift
// iCuno test

