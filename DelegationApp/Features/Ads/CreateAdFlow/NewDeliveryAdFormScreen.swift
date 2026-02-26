//
//  NewDeliveryAdFormScreen.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import SwiftUI

struct NewDeliveryAdFormScreen: View {
    @ObservedObject var draft: CreateAdDraft
    let accent: Color
    let onFinish: (AnnouncementDTO) -> Void

    @State private var goContact: Bool = false
    @State private var isValidating: Bool = false
    @State private var showValidationAlert: Bool = false
    @State private var validationText: String = ""
    private let searchService = AddressSearchService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CreateAdUI.Spacing.l) {
                header

                CreateAdSectionCard(
                    title: "Основное",
                    subtitle: "Коротко опишите задачу и бюджет (опционально).",
                    accent: accent
                ) {
                    CreateAdTextField(
                        label: "Название",
                        placeholder: "Например: Забрать посылку и привезти",
                        text: $draft.title
                    )

                    CreateAdValueField(
                        label: "Бюджет (опционально)",
                        placeholder: "0",
                        trailing: "₽",
                        text: $draft.budget
                    )
                }

                CreateAdSectionCard(
                    title: "Маршрут",
                    subtitle: "Откуда и куда нужно доставить.",
                    accent: accent
                ) {
                    CreateAdTextField(
                        label: "Адрес забора",
                        placeholder: "Введите адрес",
                        text: $draft.pickupAddress
                    )

                    CreateAdTextField(
                        label: "Адрес доставки",
                        placeholder: "Введите адрес",
                        text: $draft.dropoffAddress
                    )
                }

                CreateAdSectionCard(
                    title: "Время",
                    subtitle: "Когда можно выполнить поручение.",
                    accent: accent
                ) {
                    DatePicker("Начало", selection: $draft.startDate, displayedComponents: [.date, .hourAndMinute])
                        .font(.system(size: 16, weight: .semibold))

                    CreateAdToggleRow(title: "Указать время окончания", isOn: $draft.hasEndTime)

                    if draft.hasEndTime {
                        DatePicker("Окончание", selection: $draft.endDate, displayedComponents: [.date, .hourAndMinute])
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                CreateAdSectionCard(
                    title: "Габариты (опционально)",
                    subtitle: "Если важно — укажите размеры.",
                    accent: accent
                ) {
                    HStack(spacing: 12) {
                        CreateAdTextField(label: "Длина", placeholder: "см", text: $draft.cargoLength, keyboard: .decimalPad)
                        CreateAdTextField(label: "Ширина", placeholder: "см", text: $draft.cargoWidth, keyboard: .decimalPad)
                        CreateAdTextField(label: "Высота", placeholder: "см", text: $draft.cargoHeight, keyboard: .decimalPad)
                    }
                }

                CreateAdSectionCard(
                    title: "Подъём (опционально)",
                    subtitle: "Если нужно поднять/спустить груз.",
                    accent: accent
                ) {
                    CreateAdTextField(label: "Этаж", placeholder: "Например: 5", text: $draft.floor, keyboard: .numberPad)
                    CreateAdToggleRow(title: "Есть лифт", isOn: $draft.hasElevator)
                    CreateAdToggleRow(title: "Нужен грузчик", isOn: $draft.needLoader)
                }

                CreateAdSectionCard(
                    title: "Описание",
                    subtitle: "Любые детали, которые помогут исполнителю.",
                    accent: accent
                ) {
                    CreateAdTextArea(
                        label: "Комментарий",
                        placeholder: "Например: позвонить за 10 минут до приезда…",
                        text: $draft.notes
                    )
                }

                // Заглушка под медиа — оставляем "задел", но без логики загрузки
                CreateAdSectionCard(
                    title: "Фото и видео (позже)",
                    subtitle: "Пока без загрузки. Оставлено как точка расширения.",
                    accent: accent
                ) {
                    Text("Подключишь PhotosPicker + upload в Worker/Service.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { backToolbar }
        .navigationDestination(isPresented: $goContact) {
            AdContactScreen(
                draft: draft,
                accent: accent,
                onFinish: onFinish
            )
        }
        .alert("Проверьте данные", isPresented: $showValidationAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text(validationText)
        }
        .safeAreaInset(edge: .bottom) {
            CreateAdBottomButton(
                title: isValidating ? "Проверяем адреса..." : "Продолжить",
                accent: accent
            ) {
                guard !isValidating else { return }
                Task { @MainActor in
                    isValidating = true
                    defer { isValidating = false }

                    if let error = await draft.validateAndGeocodeMainStep(searchService: searchService) {
                        validationText = error
                        showValidationAlert = true
                        return
                    }
                    goContact = true
                }
            }
            .disabled(isValidating)
        }
    }

    private var header: some View {
        Text("Доставка и поручения")
            .font(.system(size: 28, weight: .bold))
            .padding(.top, 6)
    }

    private var backToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            CreateAdBackButton()
        }
    }
}
