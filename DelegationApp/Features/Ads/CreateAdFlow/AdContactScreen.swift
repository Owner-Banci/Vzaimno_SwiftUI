//
//  AdContactScreen.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import SwiftUI

struct AdContactScreen: View {
    @EnvironmentObject private var vm: CreateAdFlowViewModel
    @ObservedObject var draft: CreateAdDraft
    let accent: Color
    let onFinish: (AnnouncementDTO) -> Void

    @State private var showValidationAlert: Bool = false
    @State private var validationText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: CreateAdUI.Spacing.l) {
                    Text("Как с вами связаться")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.top, 6)

                    CreateAdSectionCard(
                        title: "Контакты",
                        subtitle: "Можно оставить пустым и заполнить позже в профиле — пока MVP.",
                        accent: accent
                    ) {
                        CreateAdTextField(
                            label: "Имя",
                            placeholder: "Введите имя",
                            text: $draft.contactName
                        )
                        CreateAdTextField(
                            label: "Телефон",
                            placeholder: "+7 ...",
                            text: $draft.contactPhone,
                            keyboard: .phonePad
                        )
                    }

                    CreateAdSectionCard(
                        title: "Предпочтительный способ связи",
                        subtitle: nil,
                        accent: accent
                    ) {
                        Picker("", selection: $draft.contactMethod) {
                            ForEach(CreateAdDraft.ContactMethod.allCases) { m in
                                Text(m.title).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    CreateAdSectionCard(
                        title: "Каналы (позже)",
                        subtitle: "Например: Telegram/WhatsApp — добавишь позже.",
                        accent: accent
                    ) {
                        Text("Пока оставляем как точку расширения.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            CreateAdBottomButton(
                title: vm.isSubmitting ? "Отправляем..." : "Отправить на проверку",
                accent: accent
            ) {
                guard !vm.isSubmitting else { return }

                Task { @MainActor in
                    if let error = draft.validateContactStep() {
                        validationText = error
                        showValidationAlert = true
                        return
                    }

                    let created = await vm.submit(draft: draft)
                    if let created {
                        onFinish(created)
                    } else if let errorText = vm.errorText, !errorText.isEmpty {
                        validationText = errorText
                        showValidationAlert = true
                    } else {
                        validationText = "Не удалось отправить объявление"
                        showValidationAlert = true
                    }
                }
            }
            .disabled(vm.isSubmitting)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { backToolbar }
        .alert("Проверьте данные", isPresented: $showValidationAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text(validationText)
        }
    }

    private var backToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            CreateAdBackButton()
        }
    }
}
