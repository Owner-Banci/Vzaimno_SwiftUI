//
//  AdAudienceScreen.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import SwiftUI

struct AdAudienceScreen: View {
    @EnvironmentObject private var vm: CreateAdFlowViewModel

    @ObservedObject var draft: CreateAdDraft
    let accent: Color
    let onFinish: (AnnouncementDTO) -> Void

    @State private var showError: Bool = false
    @State private var errorText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    optionsCard
                    statusHint
                }
                .padding(20)
                .padding(.top, 6)
            }

            CreateAdBottomButton(
                title: vm.isSubmitting ? "Отправляем..." : "Отправить на проверку",
                accent: accent
            ) {
                Task { @MainActor in
                    let created = await vm.submit(draft: draft)
                    if let created {
                        // Всегда закрываем create-flow и возвращаем в "Мои объявления"
                        onFinish(created)
                    } else if let txt = vm.errorText, !txt.isEmpty {
                        errorText = txt
                        showError = true
                    } else {
                        errorText = "Не удалось отправить объявление"
                        showError = true
                    }
                }
            }
            .disabled(vm.isSubmitting)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { backToolbar }
        .alert("Ошибка", isPresented: $showError) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Кому показывать объявление")
                .font(.system(size: 28, weight: .bold))
            Text("Выберите аудиторию (можно поменять позже).")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var optionsCard: some View {
        CreateAdSectionCard(
            title: "Аудитория",
            subtitle: nil,
            accent: accent
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(CreateAdDraft.Audience.allCases) { a in
                    AudienceRow(title: a.title, isSelected: draft.audience == a) {
                        draft.audience = a
                    }
                }
            }
        }
    }

    private var statusHint: some View {
        CreateAdSectionCard(
            title: "Статус",
            subtitle: "После отправки объявление появится в “Ждут действий”. На карту попадёт только после статуса “Активно”.",
            accent: accent
        ) {
            Text("Если фото/текст спорные — вы увидите пометки “!” в деталях.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var backToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            CreateAdBackButton()
        }
    }
}

private struct AudienceRow: View {
    let title: String
    let isSelected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.ColorToken.turquoise : Color.secondary)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
