import SwiftUI

struct AnnouncementDetailsScreen: View {
    private enum DetailsTab: String, CaseIterable, Identifiable {
        case details = "Детали"
        case offers = "Отклики"

        var id: String { rawValue }
    }

    let item: AnnouncementDTO
    @ObservedObject var vm: MyAdsViewModel
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @StateObject private var offersVM: AnnouncementOffersViewModel
    @State private var selectedTab: DetailsTab = .details
    @State private var showCreateFromThis: Bool = false
    @State private var prefilledDraft: CreateAdDraft?
    @State private var activeThread: ChatThreadPreview?
    @State private var showDeleteConfirmation: Bool = false
    @State private var isDeletingAnnouncement: Bool = false

    init(item: AnnouncementDTO, vm: MyAdsViewModel) {
        self.item = item
        self.vm = vm
        _offersVM = StateObject(
            wrappedValue: AnnouncementOffersViewModel(
                announcementID: item.id,
                service: vm.service,
                session: vm.session
            )
        )
    }

    private var currentItem: AnnouncementDTO {
        vm.item(with: item.id) ?? item
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsOffersSegment {
                Picker("", selection: $selectedTab) {
                    ForEach(DetailsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.ColorToken.milk.opacity(0.98))
            }

            Group {
                switch selectedTab {
                case .details:
                    detailsScroll
                case .offers:
                    offersContent
                }
            }
        }
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .navigationTitle("Детали")
        .navigationBarTitleDisplayMode(.inline)
        .hidesLiquidTabBar(reason: "announcement-details-screen")
        .onChange(of: selectedTab) { _, newTab in
            guard newTab == .offers else { return }
            Task { await offersVM.loadIfNeeded() }
        }
        .sheet(isPresented: $showCreateFromThis) {
            if let draft = prefilledDraft {
                CreateAdFlowHost(
                    service: vm.service,
                    session: vm.session,
                    prefilledDraft: draft
                ) { created in
                    vm.insertOptimistic(created)
                } onPublishCompletion: { localID, result in
                    vm.resolveSubmission(localID: localID, result: result)
                }
            }
        }
        .navigationDestination(item: $activeThread) { thread in
            ChatThreadScreen(
                thread: thread,
                service: container.chatService,
                session: vm.session
            )
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { offersVM.errorText != nil },
                set: { _ in offersVM.errorText = nil }
            )
        ) {
            Button("Ок", role: .cancel) { }
        } message: {
            Text(offersVM.errorText ?? "")
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
        .alert("Удалить объявление?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                Task { await deleteCurrentAnnouncement() }
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Объявление исчезнет из активных заданий, карты и маршрутов.")
        }
    }

    private var showsOffersSegment: Bool {
        currentItem.isActiveStatus
    }

    private var detailsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if currentItem.previewImageURL != nil {
                    AnnouncementGalleryView(announcement: currentItem, height: 240, cornerRadius: 22)
                }

                header
                moderationBlock
                detailsBlock

                if currentItem.normalizedStatus == "needs_fix" {
                    Button {
                        Task { await createNewFromThis() }
                    } label: {
                        Text("Новое объявление")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Theme.ColorToken.turquoise)
                            )
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 10)
                }

                deleteButton
            }
            .padding(16)
        }
    }

    private var offersContent: some View {
        Group {
            if offersVM.isLoading && offersVM.offers.isEmpty {
                ProgressView("Загружаем отклики…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if offersVM.offers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.wave.2")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                    Text("Откликов пока нет")
                        .font(.system(size: 18, weight: .bold))
                    Text("Когда кто-то откликнется на объявление, он появится здесь.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(offersVM.offers) { offer in
                            OfferResponseCard(
                                offer: offer,
                                isProcessing: offersVM.processingOfferID == offer.id,
                                onAccept: {
                                Task {
                                    guard let result = await offersVM.acceptOffer(offer.id) else { return }
                                    activeThread = ChatThreadPreview.acceptedOfferThread(
                                        threadID: result.threadID,
                                        performer: result.offer.performer,
                                        announcementTitle: currentItem.title
                                    )
                                    await vm.reload(showLoader: false)
                                }
                            })
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await offersVM.reload(showLoader: false)
                    await vm.reload(showLoader: false)
                }
            }
        }
        .task {
            guard selectedTab == .offers else { return }
            await offersVM.loadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentItem.title)
                .font(.system(size: 22, weight: .bold))

            HStack(spacing: 8) {
                StatusBadge(status: currentItem.normalizedStatus)
                if currentItem.hasModerationIssues {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(currentItem.maxReasonSeverity.color)
                }
                if currentItem.isActiveStatus, currentItem.offersCount > 0 {
                    Text("Отклики: \(currentItem.offersCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Capsule().fill(Theme.ColorToken.peach))
                }
            }
        }
    }

    private var moderationBlock: some View {
        let visibleReasons = currentItem.moderationPayload?.reasons.filter { !$0.isTechnicalIssue } ?? []

        return VStack(alignment: .leading, spacing: 10) {
            Text("Статус и причина")
                .font(.system(size: 16, weight: .bold))

            if let msg = currentItem.decisionMessage, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if !visibleReasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleReasons) { reason in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(reason.severity.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fieldTitle(reason.field))
                                    .font(.system(size: 14, weight: .semibold))
                                Text(reason.details)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.6)))
        .softCardShadow()
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Данные")
                .font(.system(size: 16, weight: .bold))

            fieldRow("Название", value: currentItem.title, severity: currentItem.severity(for: "title"))

            if let budgetText = currentItem.formattedBudgetText {
                fieldRow("Бюджет", value: budgetText, severity: .none)
            }

            if let notes = currentItem.data["notes"]?.stringValue, !notes.isEmpty {
                fieldRow("Описание", value: notes, severity: currentItem.severity(for: "notes"))
            }

            if currentItem.category == "delivery" {
                fieldRow(
                    "Адрес забора",
                    value: currentItem.data["pickup_address"]?.stringValue ?? "—",
                    severity: currentItem.severity(for: "pickup_address")
                )
                fieldRow(
                    "Адрес доставки",
                    value: currentItem.data["dropoff_address"]?.stringValue ?? "—",
                    severity: currentItem.severity(for: "dropoff_address")
                )
            } else if currentItem.category == "help" {
                fieldRow(
                    "Адрес",
                    value: currentItem.data["address"]?.stringValue ?? "—",
                    severity: currentItem.severity(for: "address")
                )
                if let destinationAddress = currentItem.data["destination_address"]?.stringValue,
                   !destinationAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fieldRow(
                        "Второй адрес",
                        value: destinationAddress,
                        severity: currentItem.severity(for: "destination_address")
                    )
                }
            }

            fieldRow(
                "Фото",
                value: currentItem.imageURLs.isEmpty ? "Не прикреплено" : "Прикреплено: \(currentItem.imageURLs.count)",
                severity: currentItem.severity(for: "media")
            )
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.6)))
        .softCardShadow()
    }

    private func fieldRow(_ title: String, value: String, severity: ModerationSeverity) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if severity != .none {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(severity.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
    }

    private func fieldTitle(_ field: String) -> String {
        switch field {
        case "title": return "Название"
        case "notes": return "Описание"
        case "pickup_address": return "Адрес забора"
        case "dropoff_address": return "Адрес доставки"
        case "address": return "Адрес"
        case "destination_address": return "Второй адрес"
        case "media": return "Фото"
        default: return field
        }
    }

    private func createNewFromThis() async {
        await vm.archive(currentItem.id)

        let draft = CreateAdDraft.prefilled(from: currentItem)
        draft.applyModerationMarks(from: currentItem)
        prefilledDraft = draft
        showCreateFromThis = true
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Group {
                if isDeletingAnnouncement {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Удалить объявление")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red)
            )
            .foregroundStyle(.white)
        }
        .padding(.top, 10)
        .disabled(isDeletingAnnouncement)
    }

    private func deleteCurrentAnnouncement() async {
        guard !isDeletingAnnouncement else { return }

        isDeletingAnnouncement = true
        let didDelete = await vm.delete(currentItem.id)
        isDeletingAnnouncement = false

        if didDelete {
            dismiss()
        }
    }
}



private struct OfferResponseCard: View {
    let offer: AnnouncementOffer
    let isProcessing: Bool
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                offerAvatar

                VStack(alignment: .leading, spacing: 6) {
                    Text(offer.performer?.displayName ?? "Пользователь")
                        .font(.system(size: 20, weight: .semibold))

                    if let contact = offer.performer?.contact,
                       !contact.isEmpty,
                       contact != offer.performer?.displayName {
                        Text(contact)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .semibold))
                        Text(offer.performer?.city ?? "Город не указан")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Theme.ColorToken.textSecondary)

                    Text(offer.summaryText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ColorToken.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.ColorToken.peach)
                    Text((offer.performerStats?.ratingAverage ?? 0).formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 16, weight: .bold))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Capsule().fill(Color.white.opacity(0.82)))
            }

            HStack(spacing: 26) {
                metricBlock(
                    value: (offer.performerStats?.ratingAverage ?? 0).formatted(.number.precision(.fractionLength(1))),
                    caption: "Рейтинг",
                    iconName: "star.fill",
                    iconColor: Theme.ColorToken.peach
                )
                metricBlock(
                    value: "\(offer.performerStats?.completedCount ?? 0)",
                    caption: "Выполнено"
                )
                metricBlock(
                    value: "\(offer.performerStats?.cancelledCount ?? 0)",
                    caption: "Отменено"
                )
                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.formattedPrice ?? "Без цены")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.turquoise)

                    Text(offer.createdAt, style: .relative)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                        .tint(Theme.ColorToken.turquoise)
                        .frame(width: 52, height: 52)
                } else {
                    // TODO: Вернуть отдельное отклонение, когда стабилизируем сценарий
                    // с несколькими исполнителями и финальным owner-flow.
                    actionButton(
                        systemName: offer.status == "accepted" ? "bubble.left.and.bubble.right.fill" : "checkmark",
                        fill: Theme.ColorToken.turquoise,
                        foreground: Theme.ColorToken.milk,
                        borderColor: .clear,
                        borderWidth: 0,
                        accessibilityLabel: offer.status == "accepted" ? "Открыть чат" : "Принять",
                        action: onAccept
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Theme.ColorToken.milk, Color.white.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .stroke(Theme.ColorToken.turquoise.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .softCardShadow()
    }

    private var offerAvatar: some View {
        Group {
            if let url = offer.performer?.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.white.opacity(0.92))
            .overlay(
                Text(offer.performer?.initials ?? "?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
            )
            .overlay(
                Circle()
                    .stroke(Theme.ColorToken.turquoise.opacity(0.15), lineWidth: 1)
            )
    }

    private func metricBlock(
        value: String,
        caption: String,
        iconName: String? = nil,
        iconColor: Color = Theme.ColorToken.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let iconName {
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                }
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
            }
            Text(caption)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
        }
    }

    private func actionButton(
        systemName: String,
        fill: Color,
        foreground: Color,
        borderColor: Color,
        borderWidth: CGFloat,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
