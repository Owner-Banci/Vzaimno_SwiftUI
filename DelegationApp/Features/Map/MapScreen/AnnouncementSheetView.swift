import SwiftUI

struct AnnouncementSheetView: View {
    let announcement: AnnouncementDTO
    let onRespondTap: (() -> Void)?

    @State private var showSoonAlert: Bool = false

    init(
        announcement: AnnouncementDTO,
        onRespondTap: (() -> Void)? = nil
    ) {
        self.announcement = announcement
        self.onRespondTap = onRespondTap
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
            respondButton
        }
        .alert("Скоро", isPresented: $showSoonAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text("Отклики появятся в следующем обновлении.")
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
            valueRow("Сумма", value: valueOrDash(formattedBudget))
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

    private var respondButton: some View {
        Button {
            onRespondTap?()
            showSoonAlert = true
        } label: {
            Text("Откликнуться")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.ColorToken.turquoise)
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    private var isDelivery: Bool {
        announcement.category.lowercased() == "delivery"
    }

    private var categoryTitle: String {
        switch announcement.category.lowercased() {
        case "delivery": return "Доставка и поручения"
        case "help": return "Помощь"
        default: return announcement.category
        }
    }

    private var formattedBudget: String? {
        if let number = announcement.data["budget"]?.doubleValue {
            return "\(Int(number)) ₽"
        }
        if let str = string("budget"), !str.isEmpty {
            return "\(str) ₽"
        }
        return nil
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
