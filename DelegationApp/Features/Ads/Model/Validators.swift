import Foundation

enum AdValidators {
    static let maxBudget: Double = 1_000_000
    static let minTitleLength = 3
    static let maxTitleLength = 200
    static let minAddressLength = 5
    static let minStartLeadSeconds: TimeInterval = 5 * 60
    static let minEndDeltaSeconds: TimeInterval = 10 * 60

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedAddress(_ value: String) -> String {
        let compact = trimmed(value)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return compact
    }

    static func validateTitle(_ value: String) -> String? {
        let v = trimmed(value)
        guard !v.isEmpty else {
            return "Заполните название объявления"
        }
        guard v.count >= minTitleLength else {
            return "Название должно быть не короче \(minTitleLength) символов"
        }
        guard v.count <= maxTitleLength else {
            return "Название должно быть не длиннее \(maxTitleLength) символов"
        }
        return nil
    }

    static func parseDecimal(_ value: String) -> Double? {
        let raw = trimmed(value)
        guard !raw.isEmpty else { return nil }

        let normalized = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        return Double(normalized)
    }

    static func validateBudget(_ value: String) -> String? {
        let raw = trimmed(value)
        guard !raw.isEmpty else { return nil }
        guard let number = parseDecimal(raw) else {
            return "Бюджет должен быть числом"
        }
        guard number >= 0 else {
            return "Бюджет не может быть отрицательным"
        }
        guard number <= maxBudget else {
            return "Бюджет слишком большой (максимум \(Int(maxBudget)))"
        }
        return nil
    }

    static func validateTimeWindow(startDate: Date, hasEndTime: Bool, endDate: Date) -> String? {
        let minStart = Date().addingTimeInterval(minStartLeadSeconds)
        guard startDate >= minStart else {
            return "Время начала должно быть не раньше чем через 5 минут"
        }

        guard hasEndTime else { return nil }
        guard endDate.timeIntervalSince(startDate) >= minEndDeltaSeconds else {
            return "Время окончания должно быть минимум на 10 минут позже начала"
        }
        return nil
    }

    static func validateAddress(_ value: String, fieldName: String) -> String? {
        let v = normalizedAddress(value)
        guard !v.isEmpty else {
            return "Укажите \(fieldName.lowercased())"
        }
        guard v.count >= minAddressLength else {
            return "\(fieldName) должен быть не короче \(minAddressLength) символов"
        }
        return nil
    }

    static func validateDifferentAddresses(_ pickup: String, _ dropoff: String) -> String? {
        let p = normalizedAddress(pickup).lowercased()
        let d = normalizedAddress(dropoff).lowercased()
        guard p != d else {
            return "Адрес забора и адрес доставки не должны совпадать"
        }
        return nil
    }

    static func validateDimension(_ value: String, fieldName: String, max: Double) -> String? {
        let raw = trimmed(value)
        guard !raw.isEmpty else { return nil }
        guard let number = parseDecimal(raw) else {
            return "\(fieldName) должен быть числом"
        }
        guard number > 0 else {
            return "\(fieldName) должен быть больше 0"
        }
        guard number <= max else {
            return "\(fieldName) не может быть больше \(formatNumber(max)) см"
        }
        return nil
    }

    static func validateFloor(_ value: String) -> String? {
        let raw = trimmed(value)
        guard !raw.isEmpty else { return nil }
        guard let floor = Int(raw) else {
            return "Этаж должен быть целым числом"
        }
        guard (0...200).contains(floor) else {
            return "Этаж должен быть в диапазоне 0...200"
        }
        return nil
    }

    static func normalizePhone(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        guard digits.count == 11 else { return nil }

        if digits.first == "8" {
            return "+7" + String(digits.dropFirst())
        }

        guard digits.first == "7" else { return nil }
        return "+" + digits
    }

    static func validateOptionalPhone(_ raw: String) -> (normalized: String?, error: String?) {
        let trimmedPhone = trimmed(raw)
        guard !trimmedPhone.isEmpty else {
            return (nil, nil)
        }
        guard let normalized = normalizePhone(trimmedPhone) else {
            return (nil, "Телефон должен быть в формате +7XXXXXXXXXX или 8XXXXXXXXXX")
        }
        return (normalized, nil)
    }

    private static func formatNumber(_ value: Double) -> String {
        if floor(value) == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
