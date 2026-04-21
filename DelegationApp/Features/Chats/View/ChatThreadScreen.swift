import SwiftUI

struct ChatThreadScreen: View {
    @StateObject private var vm: ChatThreadViewModel
    @State private var selectedDisputeOptionContext: DisputeOptionSelectionContext?

    init(thread: ChatThreadPreview, service: ChatService, profileService: ProfileService, session: SessionStore) {
        _vm = StateObject(wrappedValue: ChatThreadViewModel(thread: thread, service: service, profileService: profileService, session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            if shouldShowDisputePanel {
                disputePanel
                Divider().opacity(0.14)
            }
            messagesArea
            composer
        }
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .hidesLiquidTabBar(reason: "chat-thread-screen")
        .task { await vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .sheet(isPresented: $vm.isPresentingReviewSheet) {
            if let context = vm.reviewContext {
                ChatReviewSheet(
                    counterpartName: context.counterpartDisplayName ?? "Пользователь",
                    counterpartRole: context.counterpartRole ?? .performer,
                    announcementTitle: context.announcementTitle
                ) { stars, text in
                    await vm.submitReview(stars: stars, text: text)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $vm.isPresentingReportSheet) {
            ChatReportSheet(
                targetSummary: vm.reportTargetSummary,
                reasonOptions: vm.availableReportReasonOptions,
                isSubmitting: vm.isSubmittingReport
            ) { reasonCode, comment in
                await vm.submitReport(reasonCode: reasonCode, comment: comment)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.isPresentingOpenDisputeSheet) {
            OpenDisputeSheet(isSubmitting: vm.isSubmittingDisputeAction) { draft in
                await vm.openDispute(
                    problemTitle: draft.problemTitle,
                    problemDescription: draft.problemDescription,
                    requestedCompensationRub: draft.requestedCompensationRub,
                    desiredResolution: draft.desiredResolution
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.isPresentingCounterpartySheet) {
            CounterpartyDisputeSheet(
                initiatorTerms: vm.activeDispute?.initiatorTerms,
                isSubmitting: vm.isSubmittingDisputeAction,
                onAccept: {
                    await vm.acceptCounterpartyTerms()
                },
                onSubmitCounterOffer: { draft in
                    await vm.submitCounterpartyResponse(
                        responseDescription: draft.responseDescription,
                        acceptableRefundPercent: draft.acceptableRefundPercent,
                        desiredResolution: draft.desiredResolution
                    )
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedDisputeOptionContext) { selection in
            DisputeOptionDetailSheet(
                dispute: selection.dispute,
                option: selection.option,
                isSelected: selection.dispute.myVoteOptionID == selection.option.id,
                isSubmitting: vm.isSubmittingDisputeAction,
                viewerPartyRole: selection.dispute.viewerPartyRole
            ) {
                let didSubmit = await vm.selectDisputeOption(optionID: selection.option.id)
                if didSubmit {
                    selectedDisputeOptionContext = nil
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { vm.errorText != nil },
                set: { _ in vm.errorText = nil }
            )
        ) {
            Button("Ок", role: .cancel) { }
        } message: {
            Text(vm.errorText ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let url = vm.thread.partnerAvatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderAvatar
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                placeholderAvatar
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.thread.kind == "support" ? "Поддержка Vzaimno" : vm.thread.partnerName)
                    .font(.system(size: 18, weight: .bold))

                if let announcementTitle = vm.thread.announcementTitle, !announcementTitle.isEmpty {
                    Text(announcementTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                if vm.canShowOpenDisputeAction {
                    Button {
                        vm.isPresentingOpenDisputeSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.turquoise)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.86)))
                    }
                    .buttonStyle(.plain)
                }

                if vm.canPresentReportAction {
                    Button {
                        Task { await vm.presentReportSheet() }
                    } label: {
                        Group {
                            if vm.isLoadingReportOptions {
                                ProgressView()
                                    .tint(Theme.ColorToken.turquoise)
                            } else {
                                Image(systemName: "exclamationmark.bubble")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.ColorToken.turquoise)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.86))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoadingReportOptions)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.72))
    }

    private var shouldShowDisputePanel: Bool {
        vm.activeDispute != nil || vm.canShowOpenDisputeAction || vm.shouldShowDisputeThinkingState
    }

    private var disputePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Разрешение спора")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ColorToken.textPrimary)
                Spacer()
                if vm.shouldShowDisputeThinkingState {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Модель анализирует")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }
                }
            }

            if let dispute = vm.activeDispute {
                VStack(alignment: .leading, spacing: 8) {
                    Text(disputeSummaryText(dispute))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                        .multilineTextAlignment(.leading)

                    if let deadlineText = vm.disputeDeadlineText, dispute.isWaitingCounterparty {
                        Text("До конца окна ответа: \(deadlineText)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }

                if vm.canRespondAsCounterparty {
                    Button {
                        vm.isPresentingCounterpartySheet = true
                    } label: {
                        Label("Ответить на спор", systemImage: "arrowshape.turn.up.left.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.ColorToken.turquoise)
                }

                if dispute.isWaitingClarificationAnswers && !dispute.questions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Вопросы модели")
                            .font(.system(size: 13, weight: .semibold))
                        ForEach(dispute.questions.prefix(5)) { question in
                            Text("• \(question.text)")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ColorToken.textSecondary)
                        }
                        if vm.canAnswerClarifications {
                            Text("Первое ваше сообщение после этих вопросов будет зафиксировано как официальный ответ.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.9))
                    )
                }

                if (dispute.isWaitingRound1Votes || dispute.isWaitingRound2Votes), !dispute.options.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dispute.activeRound == 1 ? "Варианты решения (раунд 1)" : "Варианты решения (раунд 2)")
                            .font(.system(size: 13, weight: .semibold))

                        Text("Нажмите на вариант, чтобы посмотреть детали и подтвердить выбор.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .center, spacing: 8) {
                                ForEach(dispute.options) { option in
                                    DisputeOptionChip(
                                        title: compactDisputeOptionTitle(
                                            option: option,
                                            requestedCompensationRub: dispute.initiatorTerms.requestedCompensationRub
                                        ),
                                        isSelected: dispute.myVoteOptionID == option.id,
                                        isDisabled: !vm.canVoteInCurrentRound || vm.isSubmittingDisputeAction
                                    ) {
                                        selectedDisputeOptionContext = DisputeOptionSelectionContext(
                                            dispute: dispute,
                                            option: option
                                        )
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else if vm.canShowOpenDisputeAction {
                Text("Если по выполнению заказа возник конфликт, можно открыть спор и запустить автоматическое урегулирование через модель.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.52))
    }

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            Group {
                if vm.isLoading && vm.messages.isEmpty {
                    ProgressView("Загружаем сообщения…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.messages.isEmpty {
                    VStack(spacing: 10) {
                        Text("Чат открыт")
                            .font(.system(size: 18, weight: .bold))
                        Text("Напишите первое сообщение собеседнику.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.messages) { message in
                                VStack(spacing: 8) {
                                    MessageBubble(
                                        text: message.text,
                                        isCurrentUser: message.senderID == vm.currentUserID,
                                        isSystem: message.isSystem,
                                        timestamp: message.createdAt,
                                        isTapActionEnabled: vm.shouldShowCounterpartyTapTarget(for: message),
                                        onTapAction: {
                                            vm.openCounterpartySheetFromSystemMessage()
                                        }
                                    )

                                    if vm.shouldShowReviewAction(for: message), let context = vm.reviewContext {
                                        ReviewActionCard(
                                            context: context,
                                            isSubmitting: vm.isSubmittingReview
                                        ) {
                                            vm.isPresentingReviewSheet = true
                                        }
                                    }
                                }
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.canAnswerClarifications {
                Text("Одним сообщением ответьте на все вопросы модели. Засчитается только первый официальный ответ.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextField(vm.thread.kind == "support" ? "Напишите в поддержку..." : "Введите сообщение...", text: $vm.draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.ColorToken.turquoise.opacity(0.14), lineWidth: 1)
                    )

                Button {
                    Task { await vm.sendMessage() }
                } label: {
                    Group {
                        if vm.isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(vm.canSend ? Theme.ColorToken.turquoise : Theme.ColorToken.textSecondary.opacity(0.35))
                    )
                }
                .disabled(!vm.canSend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Theme.ColorToken.turquoise, Theme.ColorToken.peach],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(vm.thread.partnerInitials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = vm.messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    private func disputeSummaryText(_ dispute: DisputeState) -> String {
        switch dispute.status {
        case "open_waiting_counterparty":
            return "Спор открыт пользователем \(dispute.openedByDisplayName). Ожидается ответ второй стороны."
        case "model_thinking":
            return "Идёт анализ спора моделью Gemini."
        case "waiting_clarification_answers":
            return "Модель задала уточняющие вопросы. Нужны официальные ответы сторон."
        case "waiting_round_1_votes":
            return "Опубликованы 3 варианта урегулирования. Ожидаются выборы сторон."
        case "waiting_round_2_votes":
            return "Запущен второй раунд с более компромиссными вариантами."
        case "resolved":
            return dispute.resolutionSummary ?? "Спор закрыт."
        case "closed_by_acceptance":
            return dispute.resolutionSummary ?? "Спор закрыт по согласию второй стороны."
        case "awaiting_moderator":
            return dispute.resolutionSummary ?? "Автоматическая часть завершена. Ожидается модератор."
        default:
            return "Спор в обработке."
        }
    }

    private func compactDisputeOptionTitle(
        option: DisputeSettlementOption,
        requestedCompensationRub: Int
    ) -> String {
        if let amount = disputeOptionCompensationRub(
            option: option,
            requestedCompensationRub: requestedCompensationRub
        ) {
            return "\(amount.formatted(.number.grouping(.automatic))) ₽"
        }
        return shortResolutionKindTitle(option.resolutionKind)
    }

    private func disputeOptionCompensationRub(
        option: DisputeSettlementOption,
        requestedCompensationRub: Int
    ) -> Int? {
        if let compensationRub = option.compensationRub, compensationRub > 0 {
            return compensationRub
        }
        guard requestedCompensationRub > 0, let refundPercent = option.refundPercent else {
            return nil
        }
        let amount = (Double(requestedCompensationRub) * Double(refundPercent) / 100.0).rounded()
        let compensationRub = Int(amount)
        return compensationRub > 0 ? compensationRub : nil
    }

    private func shortResolutionKindTitle(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.contains("return") || value.contains("refund") {
            return "Возврат"
        }
        if value.contains("redo") || value.contains("rework") || value.contains("fix") {
            return "Переделка"
        }
        if value.contains("replace") {
            return "Замена"
        }
        if value.contains("cancel") {
            return "Отмена"
        }
        return "Вариант"
    }
}

private struct ChatReportSheet: View {
    let targetSummary: String
    let reasonOptions: [ReportReasonOption]
    let isSubmitting: Bool
    let onSubmit: (String, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReasonCode: String = ""
    @State private var comment: String = ""

    private var canSubmit: Bool {
        !selectedReasonCode.isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Причина жалобы")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.ColorToken.textPrimary)

                        Text(targetSummary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }

                    VStack(spacing: 10) {
                        ForEach(reasonOptions) { option in
                            Button {
                                selectedReasonCode = option.code
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: selectedReasonCode == option.code ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(
                                            selectedReasonCode == option.code
                                            ? Theme.ColorToken.turquoise
                                            : Theme.ColorToken.textSecondary
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.ColorToken.textPrimary)

                                        Text(option.description)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Theme.ColorToken.textSecondary)
                                            .multilineTextAlignment(.leading)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            selectedReasonCode == option.code
                                            ? Theme.ColorToken.turquoise
                                            : Theme.ColorToken.turquoise.opacity(0.12),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Комментарий")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textPrimary)

                        TextField("Опишите, что произошло", text: $comment, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
                            )
                    }
                }
                .padding(16)
            }
            .background(Theme.ColorToken.milk.ignoresSafeArea())
            .navigationTitle("Пожаловаться")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let didSubmit = await onSubmit(selectedReasonCode, comment)
                            if didSubmit {
                                dismiss()
                            }
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(Theme.ColorToken.turquoise)
                        } else {
                            Text("Отправить")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .onAppear {
                if selectedReasonCode.isEmpty {
                    selectedReasonCode = reasonOptions.first?.code ?? ""
                }
            }
        }
    }
}

private struct ReviewActionCard: View {
    let context: ReviewEligibility
    let isSubmitting: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(context.alreadySubmitted ? "Ваш отзыв уже отправлен" : "Оставьте отзыв о \(context.counterpartRole?.title.lowercased() ?? "пользователе")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textPrimary)

            if let message = context.message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
            }

            if context.canSubmit {
                Button {
                    onTap()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Оставить отзыв")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.ColorToken.turquoise)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ChatReviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let counterpartName: String
    let counterpartRole: ReviewRole
    let announcementTitle: String?
    let onSubmit: (Int, String) async -> Bool

    @State private var selectedStars: Int = 5
    @State private var comment: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Оцените \(counterpartRole.title.lowercased())")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Theme.ColorToken.textPrimary)

                        Text(counterpartName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textSecondary)

                        if let announcementTitle, !announcementTitle.isEmpty {
                            Text(announcementTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.ColorToken.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Рейтинг")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textSecondary)

                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    selectedStars = value
                                } label: {
                                    Image(systemName: value <= selectedStars ? "star.fill" : "star")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(value <= selectedStars ? Theme.ColorToken.peach : Theme.ColorToken.textSecondary.opacity(0.45))
                                        .frame(width: 42, height: 42)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text(ratingCaption)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                            .fill(Theme.ColorToken.white)
                    )
                    .softCardShadow()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Комментарий")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ColorToken.textSecondary)

                        TextEditor(text: $comment)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 140)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                                    .fill(Theme.ColorToken.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                                    .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
                            )
                    }

                    if let errorText, !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Отправить отзыв")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.ColorToken.turquoise)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
                .padding(16)
            }
            .background(Theme.ColorToken.milk.ignoresSafeArea())
            .navigationTitle("Отзыв")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private var ratingCaption: String {
        switch selectedStars {
        case 5:
            return "Отлично"
        case 4:
            return "Хорошо"
        case 3:
            return "Нормально"
        case 2:
            return "Есть вопросы"
        default:
            return "Плохо"
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let ok = await onSubmit(selectedStars, comment)
        if ok {
            dismiss()
        } else {
            errorText = "Не удалось отправить отзыв. Попробуйте ещё раз."
        }
    }
}

private struct OpenDisputeDraft {
    let problemTitle: String
    let problemDescription: String
    let requestedCompensationRub: Int
    let desiredResolution: String
}

private struct OpenDisputeSheet: View {
    let isSubmitting: Bool
    let onSubmit: (OpenDisputeDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var problemTitle: String = "Спор по качеству выполнения"
    @State private var problemDescription: String = ""
    @State private var requestedCompensationText: String = ""
    @State private var desiredResolution: String = "partial_refund"

    private var canSubmit: Bool {
        !problemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Тема спора") {
                    TextField("Короткий заголовок", text: $problemTitle)
                }

                Section("Что произошло") {
                    TextEditor(text: $problemDescription)
                        .frame(minHeight: 120)
                }

                Section("Сумма компенсации, ₽") {
                    TextField("Например 1500", text: $requestedCompensationText)
                        .keyboardType(.numberPad)
                }

                Section("Желаемое решение") {
                    Picker("Тип", selection: $desiredResolution) {
                        Text("Частичный возврат").tag("partial_refund")
                        Text("Полный возврат").tag("full_refund")
                        Text("Переделка услуги").tag("redo")
                        Text("Иное").tag("other")
                    }
                }
            }
            .navigationTitle("Открыть спор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let didSubmit = await onSubmit(
                                OpenDisputeDraft(
                                    problemTitle: problemTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                    problemDescription: problemDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                                    requestedCompensationRub: Int(requestedCompensationText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
                                    desiredResolution: desiredResolution
                                )
                            )
                            if didSubmit {
                                dismiss()
                            }
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(Theme.ColorToken.turquoise)
                        } else {
                            Text("Отправить")
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}

private struct CounterpartyDisputeDraft {
    let responseDescription: String
    let acceptableRefundPercent: Int
    let desiredResolution: String
}

private struct CounterpartyDisputeSheet: View {
    let initiatorTerms: DisputeInitiatorTerms?
    let isSubmitting: Bool
    let onAccept: () async -> Bool
    let onSubmitCounterOffer: (CounterpartyDisputeDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .accept
    @State private var responseDescription: String = ""
    @State private var acceptableRefundPercent: Double = 50
    @State private var desiredResolution: String = "partial_refund"

    enum Mode: String, CaseIterable {
        case accept
        case disagree
    }

    private var canSubmit: Bool {
        switch mode {
        case .accept:
            return !isSubmitting
        case .disagree:
            return !responseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let initiatorTerms {
                    Section("Условия первой стороны") {
                        LabeledContent("Сумма", value: "\(initiatorTerms.requestedCompensationRub.formatted(.number.grouping(.automatic))) ₽")
                        LabeledContent("Решение", value: initiatorTerms.desiredResolution)
                        if !initiatorTerms.problemTitle.isEmpty {
                            LabeledContent("Тема", value: initiatorTerms.problemTitle)
                        }
                    }
                }

                Section("Ваш сценарий") {
                    Picker("Режим", selection: $mode) {
                        Text("Согласиться").tag(Mode.accept)
                        Text("Не согласиться").tag(Mode.disagree)
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .disagree {
                    Section("Ваша версия") {
                        TextEditor(text: $responseDescription)
                            .frame(minHeight: 120)
                    }
                    Section("На какой возврат согласны") {
                        Slider(value: $acceptableRefundPercent, in: 0...100, step: 5)
                        Text("\(Int(acceptableRefundPercent))%")
                    }
                    Section("Предпочитаемое решение") {
                        Picker("Тип", selection: $desiredResolution) {
                            Text("Частичный возврат").tag("partial_refund")
                            Text("Полный возврат").tag("full_refund")
                            Text("Переделка услуги").tag("redo")
                            Text("Иное").tag("other")
                        }
                    }
                }
            }
            .navigationTitle("Ответ на спор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            let didSubmit: Bool
                            if mode == .accept {
                                didSubmit = await onAccept()
                            } else {
                                didSubmit = await onSubmitCounterOffer(
                                    CounterpartyDisputeDraft(
                                        responseDescription: responseDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                                        acceptableRefundPercent: Int(acceptableRefundPercent),
                                        desiredResolution: desiredResolution
                                    )
                                )
                            }
                            if didSubmit {
                                dismiss()
                            }
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(Theme.ColorToken.turquoise)
                        } else {
                            Text(mode == .accept ? "Согласиться" : "Отправить")
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}

private struct DisputeOptionSelectionContext: Identifiable {
    let dispute: DisputeState
    let option: DisputeSettlementOption

    var id: String {
        "\(dispute.id):\(option.id)"
    }
}

private struct DisputeOptionChip: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.turquoise)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ColorToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isSelected ? Theme.ColorToken.turquoise : Theme.ColorToken.turquoise.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct DisputeOptionDetailSheet: View {
    let dispute: DisputeState
    let option: DisputeSettlementOption
    let isSelected: Bool
    let isSubmitting: Bool
    let viewerPartyRole: String?
    let onConfirm: () async -> Void

    @Environment(\.dismiss) private var dismiss

    private var shortTitle: String {
        if let compensationRub = effectiveCompensationRub {
            return "\(compensationRub.formatted(.number.grouping(.automatic))) ₽"
        }
        return shortResolutionKindTitle(option.resolutionKind)
    }

    private var effectiveCompensationRub: Int? {
        if let compensationRub = option.compensationRub, compensationRub > 0 {
            return compensationRub
        }
        guard dispute.initiatorTerms.requestedCompensationRub > 0, let refundPercent = option.refundPercent else {
            return nil
        }
        let amount = (Double(dispute.initiatorTerms.requestedCompensationRub) * Double(refundPercent) / 100.0).rounded()
        let compensationRub = Int(amount)
        return compensationRub > 0 ? compensationRub : nil
    }

    private var roleSpecificReason: String {
        let role = viewerPartyRole?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if role == "performer" {
            return normalizedText(option.performerAction)
            ?? normalizedText(option.description)
            ?? "Модель считает это условие реалистичным для быстрого урегулирования."
        }
        return normalizedText(option.customerAction)
        ?? normalizedText(option.description)
        ?? "Модель считает это условие реалистичным для быстрого урегулирования."
    }

    private var canConfirm: Bool {
        !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Вариант")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                        Text(shortTitle)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.ColorToken.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Детали")
                            .font(.system(size: 14, weight: .semibold))

                        if let compensationRub = effectiveCompensationRub {
                            LabeledContent(
                                "Итоговая сумма",
                                value: "\(compensationRub.formatted(.number.grouping(.automatic))) ₽"
                            )
                        }

                        if let refundPercent = option.refundPercent {
                            LabeledContent("Процент", value: "\(refundPercent)%")
                        }

                        LabeledContent("Формат", value: shortResolutionKindTitle(option.resolutionKind))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Почему это может быть выгодно вам")
                            .font(.system(size: 14, weight: .semibold))
                        Text(roleSpecificReason)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                    )

                    if let optionDescription = normalizedText(option.description) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Комментарий модели")
                                .font(.system(size: 13, weight: .semibold))
                            Text(optionDescription)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ColorToken.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                        )
                    }
                }
                .padding(16)
            }
            .background(Theme.ColorToken.milk.ignoresSafeArea())
            .navigationTitle("Подтверждение варианта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await onConfirm()
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(Theme.ColorToken.turquoise)
                        } else {
                            Text(isSelected ? "Выбрано" : "Выбрать")
                        }
                    }
                    .disabled(!canConfirm)
                }
            }
        }
    }

    private func shortResolutionKindTitle(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.contains("return") || value.contains("refund") {
            return "Возврат"
        }
        if value.contains("redo") || value.contains("rework") || value.contains("fix") {
            return "Переделка"
        }
        if value.contains("replace") {
            return "Замена"
        }
        if value.contains("cancel") {
            return "Отмена"
        }
        return "Вариант"
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
}

private struct MessageBubble: View {
    let text: String
    let isCurrentUser: Bool
    let isSystem: Bool
    let timestamp: Date
    let isTapActionEnabled: Bool
    let onTapAction: () -> Void

    var body: some View {
        Group {
            if isSystem {
                VStack(spacing: 4) {
                    Text(text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)

                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.88))
                )
                .overlay(
                    Capsule()
                        .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if isTapActionEnabled {
                        Text("Нажмите, чтобы ответить")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Theme.ColorToken.turquoise.opacity(0.18))
                            )
                            .foregroundStyle(Theme.ColorToken.textPrimary)
                            .padding(.trailing, 10)
                            .padding(.bottom, -6)
                    }
                }
                .onTapGesture {
                    guard isTapActionEnabled else { return }
                    onTapAction()
                }
            } else {
                HStack {
                    if isCurrentUser { Spacer(minLength: 48) }

                    VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                        Text(text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isCurrentUser ? .white : Theme.ColorToken.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isCurrentUser ? Color.white.opacity(0.75) : Theme.ColorToken.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isCurrentUser ? Theme.ColorToken.turquoise : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.ColorToken.turquoise.opacity(isCurrentUser ? 0 : 0.12), lineWidth: 1)
                    )

                    if !isCurrentUser { Spacer(minLength: 48) }
                }
            }
        }
    }
}
