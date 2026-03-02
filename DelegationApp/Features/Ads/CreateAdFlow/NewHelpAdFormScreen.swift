import SwiftUI

struct NewHelpAdFormScreen: View {
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
                        placeholder: "Например: Помочь донести сумки",
                        text: $draft.title
                    )

                    CreateAdValueField(
                        label: "Бюджет (опционально)",
                        placeholder: "0",
                        trailing: "",
                        text: $draft.budget
                    )
                }

                CreateAdSectionCard(
                    title: "Адрес",
                    subtitle: "Где нужна помощь.",
                    accent: accent
                ) {
                    CreateAdTextField(
                        label: "Адрес",
                        placeholder: "Введите адрес",
                        text: $draft.helpAddress
                    )
                }

                CreateAdSectionCard(
                    title: "Время",
                    subtitle: "Когда можно выполнить поручение.",
                    accent: accent
                ) {
                    DatePicker(
                        "Начало",
                        selection: $draft.startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(.system(size: 16, weight: .semibold))

                    CreateAdToggleRow(title: "Указать время окончания", isOn: $draft.hasEndTime)

                    if draft.hasEndTime {
                        DatePicker(
                            "Окончание",
                            selection: $draft.endDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .font(.system(size: 16, weight: .semibold))
                    }
                }

                CreateAdSectionCard(
                    title: "Описание",
                    subtitle: "Любые детали, которые помогут исполнителю.",
                    accent: accent
                ) {
                    CreateAdTextArea(
                        label: "Комментарий",
                        placeholder: "Например: работа на 30 минут, перчатки не нужны…",
                        text: $draft.notes
                    )
                }

                // Фото: уже подключено через AdMediaPickerSection
                CreateAdSectionCard(
                    title: "Фото",
                    subtitle: "Загрузите фото (до 3). Модерация — на сервере.",
                    accent: accent
                ) {
                    AdMediaPickerSection(draft: draft)
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
                title: isValidating ? "Проверяем адрес." : "Продолжить",
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
        Text("Помощь")
            .font(.system(size: 28, weight: .bold))
            .padding(.top, 6)
    }

    private var backToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            CreateAdBackButton()
        }
    }
}
