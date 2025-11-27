//import SwiftUI
//
//// MARK: - Экран "Карта"
//
///// Основной экран "Карта": поиск, фильтры, карта, плюс-кнопка.
//struct MapScreen: View {
//    @StateObject private var vm: MapViewModel
//    @State private var showCreate = false
//
//    /// Текущий режим отображения карты (реальная карта / заглушка).
//    private let mapMode: MapDisplayMode
//
//    init(
//        vm: MapViewModel,
//        mapMode: MapDisplayMode = MapDisplayConfig.defaultMode()
//    ) {
//        _vm = StateObject(wrappedValue: vm)
//        self.mapMode = mapMode
//    }
//
//    var body: some View {
//        VStack() {
//            searchBar
//            errorLabel
//            chipsRow
//            mapArea
//        }
//        .background(Theme.ColorToken.milk)
////        .navigationTitle("Карта")
//        
//    }
//
//    // MARK: - Подвью
//
//    /// Поисковая строка.
//    private var searchBar: some View {
//        HStack(spacing: 8) {
//            Image(systemName: "magnifyingglass")
////                .foregroundColor(Theme.ColorToken.textSecondary)
//                .foregroundColor(Color.red)
//
//            TextField(
//                "Введите адрес",
//                text: $vm.searchText,
//                onCommit: vm.performSearch
//            )
//            .textFieldStyle(.plain)
//
//            if !vm.searchText.isEmpty {
//                Button {
//                    vm.searchText = ""
//                } label: {
//                    Image(systemName: "xmark.circle.fill")
//                        .foregroundColor(Theme.ColorToken.textSecondary)
//                        .imageScale(.medium)
//                }
//            }
//
//            Button(action: vm.performSearch) {
//                Text("Найти")
//                    .font(.system(size: 15, weight: .semibold))
//            }
//        }
////        .padding(.horizontal, 16)
//        .background(Color.blue)
//        .softCardShadow()
////        .ignoresSafeArea()
//    }
//
//    /// Сообщение об ошибке поиска (если есть).
//    private var errorLabel: some View {
//        Group {
//            if let message = vm.errorMessage {
//                Text(message)
//                    .font(.caption)
//                    .foregroundColor(.red)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.horizontal, 16)
//                    .padding(.top, 4)
//            }
//        }
//    }
//
//    /// Горизонтальный список чипов-фильтров.
//    private var chipsRow: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: Theme.Spacing.m) {
//                ForEach(vm.chips, id: \.self) { chip in
//                    FilterChip(
//                        title: chip,
//                        isSelected: Binding(
//                            get: { vm.selected.contains(chip) },
//                            set: { isOn in
//                                if isOn {
//                                    vm.selected.insert(chip)
//                                } else {
//                                    vm.selected.remove(chip)
//                                }
//                            }
//                        )
//                    )
//                }
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 8)
//        }
//        .background(Color.green)
//    }
//
//    /// Область карты + плавающая кнопка.
//    private var mapArea: some View {
//        ZStack(alignment: .bottom) {
//            MapCanvasView(centerPoint: $vm.centerPoint, mode: mapMode)
//        }
//    }
//}
//
//// MARK: - Preview
////#Preview {
////    let service = MockTaskService()
////    let vm = MapViewModel(service: service)
////    MapScreen(vm: vm, mapMode: .placeholder)
////}
//
//
//// MapCanvasView.swift
//// iCuno test
//

//
//  MapScreen.swift
//  iCuno test
//
//  Экран "Карта": поиск, фильтры-чипы и сама карта.
//

import SwiftUI

// MARK: - Экран "Карта"

struct MapScreen: View {
    @StateObject private var vm: MapViewModel
    @State private var showCreate = false

    /// Режим отображения карты (настоящая карта / плейсхолдер).
    private let mapMode: MapDisplayMode

    init(
        vm: MapViewModel,
        mapMode: MapDisplayMode = MapDisplayConfig.defaultMode()
    ) {
        _vm = StateObject(wrappedValue: vm)
        self.mapMode = mapMode
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Задний слой — Яндекс-карта на весь экран
            mapArea
//                .background(Color.green)
//                .cornerRadius(15)

            // Верхний слой — поиск + ошибка + чипсы
            VStack(spacing: 5) {
                // небольшой отступ от статус-бара
                Spacer().frame(height: 50)

                searchBar
//                    .background(Color.red)
                    .background(Color.clear)
                    .cornerRadius(15)
                errorLabel
                    .background(Color.clear)
                    .cornerRadius(15)
                chipsRow
                    .background(Color.clear)
                    .cornerRadius(15)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .ignoresSafeArea()
            
        }
    }

    // MARK: - Сабвью

    /// Поисковая строка.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.ColorToken.textSecondary)

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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // карточка на «стеклянном» фоне поверх карты
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .softCardShadow()
    }

    /// Сообщение об ошибке (если есть).
    private var errorLabel: some View {
        Group {
            if let message = vm.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Горизонтальный список фильтров-чипсов.
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
            .padding(0)
        }
        // важное изменение: НЕТ .background(Color.green)
        // фон прозрачный → чипсы "висят" над картой
    }

    /// Слой с картой.
    private var mapArea: some View {
        MapCanvasView(centerPoint: $vm.centerPoint, mode: mapMode)
            .ignoresSafeArea(edges: .top) // карта под всей версткой и под системными бары
    }
}
