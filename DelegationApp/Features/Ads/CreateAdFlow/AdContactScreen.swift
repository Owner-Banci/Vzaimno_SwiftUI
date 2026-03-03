//
//  AdContactScreen.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import SwiftUI

struct AdContactScreen: View {
    @ObservedObject var draft: CreateAdDraft
    let accent: Color
    let onFinish: (AnnouncementDTO) -> Void

    @State private var goAudience: Bool = false
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

            CreateAdBottomButton(title: "Продолжить", accent: accent) {
                if let error = draft.validateContactStep() {
                    validationText = error
                    showValidationAlert = true
                } else {
                    goAudience = true
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { backToolbar }
        .alert("Проверьте данные", isPresented: $showValidationAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text(validationText)
        }
        .navigationDestination(isPresented: $goAudience) {
            AdAudienceScreen(
                draft: draft,
                accent: accent,
                onFinish: onFinish
            )
        }
    }

    private var backToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            CreateAdBackButton()
        }
    }
}
