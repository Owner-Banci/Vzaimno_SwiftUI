import SwiftUI

struct AnnouncementSheetView: View {
    let announcement: AnnouncementDTO
    let onRespondTap: (() -> Void)?

    private let service: AnnouncementService
    @ObservedObject private var session: SessionStore

    @State private var messageText: String = ""
    @State private var selectedPrice: Int
    @State private var isPricePickerPresented: Bool = false
    @State private var isSubmittingQuick: Bool = false
    @State private var isSubmittingPriced: Bool = false
    @State private var alertState: SheetAlertState?

    init(
        announcement: AnnouncementDTO,
        service: AnnouncementService,
        session: SessionStore,
        onRespondTap: (() -> Void)? = nil
    ) {
        self.announcement = announcement
        self.service = service
        self.onRespondTap = onRespondTap
        _session = ObservedObject(wrappedValue: session)
        _selectedPrice = State(initialValue: Self.defaultOfferPrice(for: announcement))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if announcement.previewImageURL != nil {
                    AnnouncementGalleryView(announcement: announcement, height: 220, cornerRadius: 22)
                }
                header
                addressSection
                timeSection
                budgetSection
                detailsSection
                contactsSection
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom) {
            responseComposer
        }
        .sheet(isPresented: $isPricePickerPresented) {
            OfferPricePickerSheet(
                price: $selectedPrice,
                budgetHint: announcement.formattedBudgetText
            ) {
                Task { await submitOffer(proposedPrice: selectedPrice) }
            }
            .presentationDetents([.height(356)])
            .presentationDragIndicator(.visible)
        }
        .alert(item: $alertState) { state in
            Alert(
                title: Text(state.title),
                message: Text(state.message),
                dismissButton: .default(Text("Ок"))
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(announcement.title)
                .font(.system(size: 24, weight: .bold))

            Text(categoryTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.ColorToken.turquoise))
        }
    }

    private var addressSection: some View {
        Group {
            if isDelivery {
                SectionCard(title: "Адреса") {
                    valueRow("Откуда", value: valueOrDash(string("pickup_address")))
                    valueRow("Куда", value: valueOrDash(string("dropoff_address")))
                }
            } else if let destinationAddress = string("destination_address") {
                SectionCard(title: "Адреса") {
                    valueRow("Где", value: valueOrDash(string("address")))
                    valueRow("Куда", value: destinationAddress)
                }
            } else {
                SectionCard(title: "Адрес") {
                    valueRow("Где", value: valueOrDash(string("address")))
                }
            }
        }
    }

    private var timeSection: some View {
        SectionCard(title: "Время") {
            valueRow("Начало", value: valueOrDash(formattedDate(string("start_at"))))

            if bool("has_end_time") == true {
                valueRow("Окончание", value: valueOrDash(formattedDate(string("end_at"))))
            }
        }
    }

    private var budgetSection: some View {
        SectionCard(title: "Бюджет") {
            valueRow("Сумма", value: valueOrDash(announcement.formattedBudgetText))
        }
    }

    private var detailsSection: some View {
        Group {
            if isDelivery {
                SectionCard(title: "Детали") {
                    if let dimensions = dimensionsText {
                        valueRow("Габариты", value: dimensions)
                    }

                    if let floorText = floorText {
                        valueRow("Подъём", value: floorText)
                    }

                    valueRow("Лифт", value: bool("has_elevator") == true ? "Есть" : "Нет")
                    valueRow("Грузчик", value: bool("need_loader") == true ? "Нужен" : "Не нужен")
                    valueRow("Фото", value: announcement.imageURLs.isEmpty ? "Не прикреплено" : "Прикреплено: \(announcement.imageURLs.count)")
                }
            } else {
                SectionCard(title: "Детали") {
                    valueRow("Фото", value: announcement.imageURLs.isEmpty ? "Не прикреплено" : "Прикреплено: \(announcement.imageURLs.count)")
                }
            }
        }
    }

    private var contactsSection: some View {
        SectionCard(title: "Контакты") {
            if let name = string("contact_name"), !name.isEmpty {
                valueRow("Имя", value: name)
            }
            if let phone = string("contact_phone"), !phone.isEmpty {
                valueRow("Телефон", value: phone)
            }
            if let method = contactMethodTitle {
                valueRow("Связь", value: method)
            }

            if string("contact_name") == nil,
               string("contact_phone") == nil,
               contactMethodTitle == nil {
                valueRow("Контакты", value: "—")
            }
        }
    }

    private var responseComposer: some View {
        VStack(spacing: 8) {
            if isOwnAnnouncement {
                statusBanner(
                    title: "Это ваше объявление",
                    subtitle: "Отклики доступны только для других пользователей."
                )
            } else if !announcement.canAcceptOffers {
                statusBanner(
                    title: "Отклики закрыты",
                    subtitle: "Задание уже принято или больше не доступно для новых исполнителей."
                )
            } else if session.token == nil {
                statusBanner(
                    title: "Нужна авторизация",
                    subtitle: "Войдите в аккаунт, чтобы откликнуться на объявление."
                )
            } else {
                VStack(spacing: 10) {
                    TextField("Напишите сообщение заказчику...", text: $messageText, axis: .vertical)
                        .lineLimit(1...2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Theme.ColorToken.turquoise.opacity(0.15), lineWidth: 1)
                        )

                    HStack(spacing: 10) {
                        Button {
                            Task { await submitOffer(proposedPrice: nil) }
                        } label: {
                            composerButtonLabel(
                                title: "Быстрый отклик",
                                subtitle: announcement.quickOfferPrice.map {
                                    "Мин. цена \($0.formatted(.number.grouping(.automatic))) ₽"
                                } ?? "Мин. цена",
                                isLoading: isSubmittingQuick,
                                isPrimary: true
                            )
                        }
                        .disabled(isBusy)

                        Button {
                            isPricePickerPresented = true
                        } label: {
                            composerButtonLabel(
                                title: "Своя цена",
                                subtitle: selectedPrice > 0
                                    ? "\(selectedPrice.formatted(.number.grouping(.automatic))) ₽"
                                    : "Указать сумму",
                                isLoading: isSubmittingPriced,
                                isPrimary: false
                            )
                        }
                        .disabled(isBusy)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var isDelivery: Bool {
        announcement.category.lowercased() == "delivery"
    }

    private var isOwnAnnouncement: Bool {
        session.me?.id == announcement.user_id
    }

    private var isBusy: Bool {
        isSubmittingQuick || isSubmittingPriced
    }

    private var categoryTitle: String {
        switch announcement.category.lowercased() {
        case "delivery": return "Доставка и поручения"
        case "help": return "Помощь"
        default: return announcement.category
        }
    }

    private var dimensionsText: String? {
        let length = announcement.data["cargo_length"]?.doubleValue
        let width = announcement.data["cargo_width"]?.doubleValue
        let height = announcement.data["cargo_height"]?.doubleValue

        var parts: [String] = []
        if let length { parts.append("Д \(formatNumber(length)) см") }
        if let width { parts.append("Ш \(formatNumber(width)) см") }
        if let height { parts.append("В \(formatNumber(height)) см") }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var floorText: String? {
        let floorValue = announcement.data["floor"]?.doubleValue
        guard let floorValue else { return nil }
        return "\(Int(floorValue)) этаж"
    }

    private var contactMethodTitle: String? {
        guard let raw = string("contact_method") else { return nil }
        switch raw {
        case "calls_and_messages": return "Звонки и сообщения"
        case "messages_only": return "Только сообщения"
        case "calls_only": return "Только звонки"
        default: return raw
        }
    }

    private func string(_ key: String) -> String? {
        guard let raw = announcement.data[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        return raw.isEmpty ? nil : raw
    }

    private func bool(_ key: String) -> Bool? {
        announcement.data[key]?.boolValue
    }

    private func formattedDate(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        parser.formatOptions = [.withInternetDateTime]
        if let date = parser.date(from: iso) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return iso
    }

    private func valueOrDash(_ value: String?) -> String {
        if let value, !value.isEmpty { return value }
        return "—"
    }

    private func formatNumber(_ value: Double) -> String {
        if floor(value) == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    @ViewBuilder
    private func valueRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func composerButtonLabel(
        title: String,
        subtitle: String,
        isLoading: Bool,
        isPrimary: Bool
    ) -> some View {
        VStack(spacing: 2) {
            if isLoading {
                ProgressView()
                    .tint(isPrimary ? .white : Theme.ColorToken.turquoise)
            } else {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold))
                .opacity(isLoading ? 0.85 : 1)
        }
        .foregroundStyle(isPrimary ? Color.white : Theme.ColorToken.turquoise)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isPrimary ? Theme.ColorToken.turquoise : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.ColorToken.turquoise.opacity(isPrimary ? 0 : 0.22), lineWidth: 1)
        )
    }

    private func statusBanner(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }

    private func submitOffer(proposedPrice: Int?) async {
        guard let token = session.token else {
            alertState = SheetAlertState(title: "Нужна авторизация", message: "Войдите в аккаунт и повторите попытку.")
            return
        }

        guard announcement.canAcceptOffers else {
            alertState = SheetAlertState(title: "Отклики закрыты", message: "По этому заданию больше нельзя отправить новый отклик.")
            return
        }

        if proposedPrice == nil {
            isSubmittingQuick = true
        } else {
            isSubmittingPriced = true
        }
        defer {
            isSubmittingQuick = false
            isSubmittingPriced = false
        }

        do {
            let quickPrice = announcement.quickOfferPrice ?? Self.defaultOfferPrice(for: announcement)
            let pricingMode: OfferPricingMode = proposedPrice == nil ? .quickMinPrice : .counterPrice
            let effectiveProposedPrice = proposedPrice ?? quickPrice
            let agreedPrice = proposedPrice == nil ? quickPrice : nil
            let minimumPriceAccepted = proposedPrice == nil

            _ = try await service.createOffer(
                token: token,
                announcementId: announcement.id,
                message: messageText,
                proposedPrice: effectiveProposedPrice,
                pricingMode: pricingMode,
                agreedPrice: agreedPrice,
                minimumPriceAccepted: minimumPriceAccepted
            )
            onRespondTap?()
            messageText = ""
            alertState = SheetAlertState(title: "Отклик отправлен", message: "Заказчик увидит ваш отклик в своих объявлениях.")
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return
            }
            alertState = SheetAlertState(title: "Не удалось отправить отклик", message: error.localizedDescription)
        }
    }

    private static func defaultOfferPrice(for announcement: AnnouncementDTO) -> Int {
        if let quickOfferPrice = announcement.quickOfferPrice {
            return max(0, quickOfferPrice)
        }
        if let budgetMin = announcement.budgetMinValue, let budgetMax = announcement.budgetMaxValue {
            return max(budgetMin, (budgetMin + budgetMax) / 2)
        }
        if let budgetMin = announcement.budgetMinValue {
            return max(0, budgetMin)
        }
        if let budgetMax = announcement.budgetMaxValue {
            return max(0, budgetMax)
        }
        if let budget = announcement.budgetValue {
            return max(0, budget)
        }
        return 0
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .bold))

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.ColorToken.turquoise.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct OfferPricePickerSheet: View {
    @Binding var price: Int
    let budgetHint: String?
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var textValue: String = ""

    private let step: Int = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Предложенная цена")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button("Закрыть") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
            }

            Text(price > 0 ? "\(price.formatted(.number.grouping(.automatic))) ₽" : "Укажите цену")
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)

            TextField("Введите сумму", text: $textValue)
                .keyboardType(.numberPad)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.ColorToken.turquoise.opacity(0.15), lineWidth: 1)
                )
                .onChange(of: textValue) { _, newValue in
                    applyText(newValue)
                }

            HStack(spacing: 16) {
                Text("Шаг \(step) ₽")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                HStack(spacing: 12) {
                    priceChangeButton(systemName: "minus") {
                        change(by: -step)
                    }
                    priceChangeButton(systemName: "plus") {
                        change(by: step)
                    }
                }
            }

            if let budgetHint, !budgetHint.isEmpty {
                Text("Ориентир по объявлению: \(budgetHint)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ColorToken.textSecondary)
            }

            Button {
                onConfirm()
                dismiss()
            } label: {
                Text("Отправить отклик")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.ColorToken.turquoise)
                    )
            }
            .disabled(price <= 0)
            .opacity(price > 0 ? 1 : 0.55)
        }
        .padding(20)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
        .onAppear {
            textValue = price > 0 ? String(price) : ""
        }
    }

    private func priceChangeButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 68, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.ColorToken.turquoise.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func applyText(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        if digits != raw {
            textValue = digits
        }

        guard !digits.isEmpty, let typedValue = Int(digits) else {
            price = 0
            return
        }

        price = max(0, typedValue)
    }

    private func change(by delta: Int) {
        price = max(0, price + delta)
        textValue = price > 0 ? String(price) : ""
    }
}

private struct SheetAlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
