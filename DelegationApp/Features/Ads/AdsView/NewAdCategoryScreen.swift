import SwiftUI

struct StructuredCreateAdScreen: View {
    @EnvironmentObject private var vm: CreateAdFlowViewModel

    @ObservedObject var draft: CreateAdDraft
    let onClose: () -> Void
    let onFinish: (AnnouncementDTO) -> Void

    @State private var showError: Bool = false
    @State private var errorText: String = ""
    @State private var isMiniSummaryExpanded: Bool = false
    @State private var showsExactDimensions: Bool = false

    private let accent = Theme.ColorToken.turquoise
    private let sectionAccent = Theme.ColorToken.turquoise
    private let actionColumns = [GridItem(.adaptive(minimum: 154), spacing: 10)]
    private let compactColumns = [GridItem(.adaptive(minimum: 112), spacing: 10)]
    private let toggleColumns = [GridItem(.adaptive(minimum: 170), spacing: 10)]
    private let dimensionColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                actionSection

                if draft.showsStructuredSections {
                    objectSection
                    sourceSection

                    if draft.showsDestinationSection {
                        destinationSection
                    }

                    timeSection

                    if !draft.availableConditionOptions.isEmpty {
                        conditionsSection
                    }

                    if draft.showsCargoSection {
                        cargoSection
                    }

                    budgetSection
                    contactSection
                    additionalSection
                    finalSummarySection
                } else {
                    helperSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("Новое объявление")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            CreateAdStickyMiniSummary(
                title: draft.resolvedTitle,
                actionText: draft.actionType?.title ?? "Черновик",
                objectText: miniObjectText,
                routeText: draft.routeSummary,
                whenText: draft.timeSummary,
                priceText: draft.budgetSummary,
                isExpanded: $isMiniSummaryExpanded,
                accent: accent
            )
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 6)
            .background(.ultraThinMaterial)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.turquoise)
                        .padding(6)
                }
                .accessibilityLabel("Закрыть")
            }
        }
        .alert("Проверьте данные", isPresented: $showError) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Соберите объявление из готовых блоков")
                .font(.system(size: 32, weight: .bold))

            Text("Сначала выберите сценарий, потом уточните детали. Категория, заголовок и итоговый payload соберутся автоматически.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var helperSection: some View {
        CreateAdSectionCard(
            title: "С чего начать",
            subtitle: "Выберите верхний сценарий. После этого экран покажет только подходящие блоки и уберёт всё лишнее.",
            accent: sectionAccent
        ) {
            Text("Минимум ручного текста: в основном чипы, переключатели, адреса и несколько коротких числовых значений.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var actionSection: some View {
        CreateAdSectionCard(
            title: "Что нужно сделать",
            subtitle: "Это главный выбор. Он определяет набор полей, итоговый заголовок и backend group.",
            accent: sectionAccent
        ) {
            LazyVGrid(columns: actionColumns, spacing: 10) {
                ForEach(CreateAdDraft.UserActionType.allCases) { action in
                    CreateAdChoiceChip(
                        title: action.title,
                        subtitle: action.subtitle,
                        systemImage: action.systemImage,
                        isSelected: draft.actionType == action,
                        accent: accent
                    ) {
                        draft.actionType = action
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var objectSection: some View {
        CreateAdSectionCard(
            title: draft.objectSectionTitle,
            subtitle: draft.objectSectionSubtitle,
            accent: sectionAccent
        ) {
            switch draft.actionType {
            case .some(.pickup), .some(.carry):
                LazyVGrid(columns: compactColumns, spacing: 10) {
                    ForEach(draft.availableGenericItemTypes) { item in
                        CreateAdChoiceChip(
                            title: item.title,
                            systemImage: item.systemImage,
                            isSelected: draft.itemType == item,
                            accent: accent,
                            compact: true
                        ) {
                            draft.itemType = item
                        }
                    }
                }

            case .some(.buy):
                LazyVGrid(columns: compactColumns, spacing: 10) {
                    ForEach(CreateAdDraft.PurchaseType.allCases) { item in
                        CreateAdChoiceChip(
                            title: item.title,
                            systemImage: item.systemImage,
                            isSelected: draft.purchaseType == item,
                            accent: accent,
                            compact: true
                        ) {
                            draft.purchaseType = item
                        }
                    }
                }

            case .some(.ride):
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        CreateAdInfoTag(title: "1 пассажир", systemImage: "person")
                        Text("Для поездки оставляем короткий сценарий без лишних параметров.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: compactColumns, spacing: 10) {
                        CreateAdChoiceChip(
                            title: "Без багажа",
                            systemImage: "figure.seated.side",
                            isSelected: !draft.needsTrunk,
                            accent: accent,
                            compact: true
                        ) {
                            draft.needsTrunk = false
                        }

                        CreateAdChoiceChip(
                            title: "Нужен багажник",
                            systemImage: "suitcase.rolling",
                            isSelected: draft.needsTrunk,
                            accent: accent,
                            compact: true
                        ) {
                            draft.needsTrunk = true
                        }
                    }
                }

            case .some(.proHelp):
                LazyVGrid(columns: compactColumns, spacing: 10) {
                    ForEach(CreateAdDraft.HelpType.allCases) { help in
                        CreateAdChoiceChip(
                            title: help.title,
                            systemImage: help.systemImage,
                            isSelected: draft.helpType == help,
                            accent: accent,
                            compact: true
                        ) {
                            draft.helpType = help
                        }
                    }
                }

                CreateAdTextField(
                    label: draft.taskBriefLabel,
                    placeholder: draft.taskBriefPlaceholder,
                    text: $draft.taskBrief
                )

            case .some(.other):
                CreateAdTextField(
                    label: draft.taskBriefLabel,
                    placeholder: draft.taskBriefPlaceholder,
                    text: $draft.taskBrief
                )

            case .none:
                EmptyView()
            }
        }
    }

    private var sourceSection: some View {
        CreateAdSectionCard(
            title: draft.sourceSectionTitle,
            subtitle: sourceSectionSubtitle,
            accent: sectionAccent
        ) {
            LazyVGrid(columns: compactColumns, spacing: 10) {
                ForEach(draft.availableSourceKinds) { option in
                    CreateAdChoiceChip(
                        title: sourceTitle(for: option),
                        systemImage: option.systemImage,
                        isSelected: draft.sourceKind == option,
                        accent: accent,
                        compact: true
                    ) {
                        draft.sourceKind = option
                    }
                }
            }

            CreateAdTextField(
                label: draft.sourceFieldLabel,
                placeholder: sourcePlaceholder,
                text: $draft.pickupAddress,
                mark: draft.moderationMarks[draft.sourceAddressModerationKey]
            )
        }
    }

    private var destinationSection: some View {
        CreateAdSectionCard(
            title: draft.destinationSectionTitle,
            subtitle: destinationSectionSubtitle,
            accent: sectionAccent
        ) {
            LazyVGrid(columns: compactColumns, spacing: 10) {
                ForEach(draft.availableDestinationKinds) { option in
                    CreateAdChoiceChip(
                        title: destinationTitle(for: option),
                        systemImage: option.systemImage,
                        isSelected: draft.destinationKind == option,
                        accent: accent,
                        compact: true
                    ) {
                        draft.destinationKind = option
                    }
                }
            }

            CreateAdTextField(
                label: draft.destinationFieldLabel,
                placeholder: destinationPlaceholder,
                text: $draft.dropoffAddress,
                mark: draft.moderationMarks[draft.destinationAddressModerationKey]
            )
        }
    }

    private var timeSection: some View {
        CreateAdSectionCard(
            title: "Когда",
            subtitle: "Сначала выберите срочность, потом при необходимости уточните крайнее время и ожидание.",
            accent: sectionAccent
        ) {
            LazyVGrid(columns: compactColumns, spacing: 10) {
                ForEach(CreateAdDraft.Urgency.allCases) { urgency in
                    CreateAdChoiceChip(
                        title: urgency.title,
                        systemImage: urgency.systemImage,
                        isSelected: draft.urgency == urgency,
                        accent: accent,
                        compact: true
                    ) {
                        draft.urgency = urgency
                    }
                }
            }

            if draft.urgency == .scheduled {
                DatePicker(
                    "Дата и время",
                    selection: $draft.startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.system(size: 16, weight: .semibold))
            } else {
                HStack(spacing: 8) {
                    CreateAdInfoTag(title: draft.timeSummary, systemImage: "clock")
                    Text("Если нужен точный слот, переключите на “Ко времени”.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            CreateAdToggleRow(title: "Указать крайнее время", isOn: $draft.hasEndTime)

            if draft.hasEndTime {
                DatePicker(
                    "Крайнее время",
                    selection: $draft.endDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.system(size: 16, weight: .semibold))
            }

            CreateAdValueField(
                label: "Сколько займёт задача",
                placeholder: "30",
                trailing: "мин",
                text: $draft.estimatedTaskMinutes
            )

            if draft.waitOnSite {
                CreateAdValueField(
                    label: "Сколько можно ждать",
                    placeholder: "10",
                    trailing: "мин",
                    text: $draft.waitingMinutes
                )
            }
        }
    }

    private var conditionsSection: some View {
        CreateAdSectionCard(
            title: "Условия выполнения",
            subtitle: "Только execution modifiers: без повторения самого действия, только важные уточнения по выполнению.",
            accent: sectionAccent
        ) {
            LazyVGrid(columns: toggleColumns, spacing: 10) {
                ForEach(draft.availableConditionOptions) { option in
                    CreateAdToggleTile(
                        title: option.title,
                        subtitle: option.subtitle,
                        systemImage: option.systemImage,
                        isOn: binding(for: option),
                        accent: accent
                    )
                }
            }

            if draft.requiresLiftToFloor {
                CreateAdTextField(
                    label: "Этаж",
                    placeholder: "Например: 5",
                    text: $draft.floor,
                    keyboard: .numberPad
                )
            }
        }
    }

    private var cargoSection: some View {
        CreateAdSectionCard(
            title: "Вес, размер и габариты",
            subtitle: "Быстрые пресеты для скорости и точные сантиметры, если важно уточнить объём груза.",
            accent: sectionAccent
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Вес")
                        .font(.system(size: 14, weight: .bold))

                    LazyVGrid(columns: compactColumns, spacing: 10) {
                        ForEach(CreateAdDraft.WeightCategory.allCases) { option in
                            CreateAdChoiceChip(
                                title: option.title,
                                isSelected: draft.weightCategory == option,
                                accent: accent,
                                compact: true
                            ) {
                                draft.weightCategory = option
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Размер")
                        .font(.system(size: 14, weight: .bold))

                    LazyVGrid(columns: compactColumns, spacing: 10) {
                        ForEach(CreateAdDraft.SizeCategory.allCases) { option in
                            CreateAdChoiceChip(
                                title: option.title,
                                isSelected: draft.sizeCategory == option,
                                accent: accent,
                                compact: true
                            ) {
                                draft.sizeCategory = option
                            }
                        }
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsExactDimensions.toggle()
                    }
                } label: {
                    HStack {
                        Text("Указать точные габариты")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.ColorToken.textPrimary)
                        Spacer()
                        Image(systemName: (showsExactDimensions || draft.hasExactDimensions) ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if showsExactDimensions || draft.hasExactDimensions {
                    LazyVGrid(columns: dimensionColumns, spacing: 12) {
                        CreateAdValueField(
                            label: "Длина",
                            placeholder: "0",
                            trailing: "см",
                            text: $draft.cargoLength
                        )
                        CreateAdValueField(
                            label: "Ширина",
                            placeholder: "0",
                            trailing: "см",
                            text: $draft.cargoWidth
                        )
                        CreateAdValueField(
                            label: "Высота",
                            placeholder: "0",
                            trailing: "см",
                            text: $draft.cargoHeight
                        )
                    }
                }
            }
        }
    }

    private var budgetSection: some View {
        let recommendation = draft.recommendedPriceRange

        return CreateAdSectionCard(
            title: "Цена",
            subtitle: "Сначала посмотрите рекомендацию, потом задайте свой диапазон, если хотите отклониться.",
            accent: sectionAccent
        ) {
            CreateAdRecommendedPriceView(
                title: recommendation.text,
                subtitle: "Оценка по сценарию, срочности, условиям и габаритам. Позже её можно заменить на серверную recommendation system.",
                accent: accent
            )

            CreateAdBudgetRangeField(
                label: "Ваш диапазон",
                accent: accent,
                minPlaceholder: recommendation.minPlaceholder,
                maxPlaceholder: recommendation.maxPlaceholder,
                minText: $draft.budgetMin,
                maxText: $draft.budgetMax
            )
        }
    }

    private var contactSection: some View {
        CreateAdSectionCard(
            title: "Контакты",
            subtitle: "Эти поля не должны быть длинными: только как удобнее связаться и для кого адресовано объявление.",
            accent: sectionAccent
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

            Picker("", selection: $draft.contactMethod) {
                ForEach(CreateAdDraft.ContactMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                Text("Для кого")
                    .font(.system(size: 14, weight: .bold))

                LazyVGrid(columns: compactColumns, spacing: 10) {
                    ForEach(CreateAdDraft.Audience.allCases) { audience in
                        CreateAdChoiceChip(
                            title: audience.title,
                            isSelected: draft.audience == audience,
                            accent: accent,
                            compact: true
                        ) {
                            draft.audience = audience
                        }
                    }
                }
            }
        }
    }

    private var additionalSection: some View {
        CreateAdSectionCard(
            title: "Дополнительно",
            subtitle: "Только необязательные уточнения: ручной заголовок, короткий комментарий и фото. Без доп. текста и фото объявление обычно проходит быстрее.",
            accent: sectionAccent
        ) {
            CreateAdTextField(
                label: "Свой заголовок (необязательно)",
                placeholder: "Оставьте пустым, если автозаголовок подходит",
                text: $draft.title,
                mark: draft.moderationMarks["title"]
            )

            CreateAdTextArea(
                label: "Комментарий",
                placeholder: notesPlaceholder,
                text: $draft.notes,
                mark: draft.moderationMarks["notes"]
            )

            AdMediaPickerSection(
                draft: draft,
                mark: draft.moderationMarks["media"]
            )
        }
    }

    private var finalSummarySection: some View {
        CreateAdSectionCard(
            title: "Итог объявления",
            subtitle: "Сначала проверьте итоговую карточку. Кнопка отправки появляется только здесь, в самом конце формы.",
            accent: sectionAccent
        ) {
            CreateAdSummaryCard(
                title: draft.resolvedTitle,
                tags: Array(draft.generatedHints.prefix(6)),
                route: draft.routeSummary,
                whenText: draft.timeSummary,
                budgetText: draft.budgetSummary,
                accent: accent
            )

            VStack(spacing: 10) {
                summaryRow(title: "Сценарий", value: draft.actionType?.title ?? "Не выбран")
                summaryRow(title: "Категория", value: draft.resolvedCategory.title)
                summaryRow(title: "Кратко", value: draft.objectSummary)
                summaryRow(title: "Маршрут", value: draft.routeSummary)
                summaryRow(title: "Когда", value: draft.timeSummary)
                summaryRow(title: "Цена", value: draft.budgetSummary)
            }

            if !draft.selectedConditionTitles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(draft.selectedConditionTitles, id: \.self) { title in
                            CreateAdInfoTag(title: title)
                        }
                    }
                }
            }

            if draft.isReadyForSubmit {
                CreateAdBottomButton(
                    title: vm.isSubmitting ? "Отправляем..." : "Отправить на проверку",
                    accent: accent,
                    floating: false,
                    isEnabled: !vm.isSubmitting
                ) {
                    guard !vm.isSubmitting else { return }
                    submit()
                }
            } else {
                CreateAdReadinessCard(
                    title: "Чтобы отправить объявление, осталось:",
                    issues: draft.submitReadinessIssues,
                    accent: accent
                )
            }
        }
    }

    private var miniObjectText: String {
        switch draft.actionType {
        case .some(.pickup), .some(.carry):
            return draft.itemType?.title ?? "Без деталей"
        case .some(.buy):
            return draft.purchaseType?.title ?? "Покупка"
        case .some(.ride):
            return draft.needsTrunk ? "С багажом" : "Без багажа"
        case .some(.proHelp):
            return draft.helpType?.title ?? "Быстрая помощь"
        case .some(.other):
            return AdValidators.trimmed(draft.taskBrief).isEmpty ? "Нестандартно" : "Есть уточнение"
        case .none:
            return "Без деталей"
        }
    }

    private var sourceSectionSubtitle: String {
        switch draft.actionType {
        case .some(.pickup):
            return "Источник задачи: у человека, в ПВЗ, в заведении или в другой точке."
        case .some(.buy):
            return "Укажите, где удобнее купить: конкретное место или понятная зона."
        case .some(.carry):
            return "Точка, откуда начинается перенос."
        case .some(.ride):
            return "Где забрать пассажира."
        case .some(.proHelp):
            return "Локация, где нужна быстрая помощь."
        case .some(.other):
            return "Одна понятная точка, с которой начинается задача."
        case .none:
            return "Выберите действие выше."
        }
    }

    private var destinationSectionSubtitle: String {
        switch draft.actionType {
        case .some(.carry):
            return "Если перенос в одной точке, адрес назначения можно не указывать."
        case .some(.ride):
            return "Куда нужно подвезти пассажира."
        default:
            return "Укажите понятную конечную точку."
        }
    }

    private var sourcePlaceholder: String {
        switch (draft.actionType, draft.sourceKind) {
        case (.some(.pickup), .some(.pickupPoint)):
            return "Например: Ozon, Пятницкая 12"
        case (.some(.pickup), .some(.venue)):
            return "Например: ресторан, аптека или салон"
        case (.some(.buy), .some(.venue)):
            return "Например: супермаркет или аптека"
        case (.some(.buy), .some(.other)):
            return "Например: рядом с метро Павелецкая"
        case (.some(.ride), _):
            return "Например: Павелецкая площадь 1"
        case (.some(.proHelp), _):
            return "Например: Лесная 10"
        default:
            return "Введите адрес"
        }
    }

    private var destinationPlaceholder: String {
        switch draft.destinationKind {
        case .some(.metro):
            return "Например: Павелецкая"
        case .some(.entrance):
            return "Например: Лесная 10"
        default:
            return "Введите адрес"
        }
    }

    private var notesPlaceholder: String {
        switch draft.actionType {
        case .some(.proHelp):
            return "Коротко уточните детали, если мастеру важно знать контекст заранее."
        case .some(.buy):
            return "Например: если товара нет, позвонить и согласовать замену."
        default:
            return "Коротко уточните детали, если это поможет исполнителю."
        }
    }

    private func sourceTitle(for option: CreateAdDraft.SourceKind) -> String {
        switch draft.actionType {
        case .some(.buy):
            switch option {
            case .venue:
                return "В заведении"
            case .address:
                return "В конкретном месте"
            case .other:
                return "Где угодно рядом"
            default:
                return option.title
            }

        case .some(.proHelp):
            switch option {
            case .address:
                return "По адресу"
            case .office:
                return "В офисе"
            case .venue:
                return "В заведении"
            default:
                return option.title
            }

        default:
            return option.title
        }
    }

    private func destinationTitle(for option: CreateAdDraft.DestinationKind) -> String {
        switch draft.actionType {
        case .some(.ride):
            switch option {
            case .metro:
                return "К метро"
            default:
                return option.title
            }
        default:
            return option.title
        }
    }

    private func binding(for option: CreateAdDraft.ConditionOption) -> Binding<Bool> {
        switch option {
        case .requiresVehicle:
            return $draft.requiresVehicle
        case .needsTrunk:
            return $draft.needsTrunk
        case .requiresCarefulHandling:
            return $draft.requiresCarefulHandling
        case .requiresLiftToFloor:
            return $draft.requiresLiftToFloor
        case .hasElevator:
            return $draft.hasElevator
        case .needsLoader:
            return $draft.needLoader
        case .waitOnSite:
            return $draft.waitOnSite
        case .callBeforeArrival:
            return $draft.callBeforeArrival
        case .requiresConfirmationCode:
            return $draft.requiresConfirmationCode
        case .contactless:
            return $draft.contactless
        case .requiresReceipt:
            return $draft.requiresReceipt
        case .photoReportRequired:
            return $draft.photoReportRequired
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .frame(width: 78, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func submit() {
        Task { @MainActor in
            let created = await vm.submit(draft: draft)
            if let created {
                onFinish(created)
            } else if let error = vm.errorText, !error.isEmpty {
                errorText = error
                showError = true
            } else {
                errorText = "Не удалось отправить объявление"
                showError = true
            }
        }
    }
}

typealias NewAdCategoryScreen = StructuredCreateAdScreen
