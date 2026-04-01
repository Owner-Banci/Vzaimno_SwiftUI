//
//  CreateAdUI.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import SwiftUI
import UIKit

enum CreateAdUI {
    enum Spacing {
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
    }

    enum Radius {
        static let card: CGFloat = 18
    }

    enum Palette {
        static let turquoise = Theme.ColorToken.turquoise
        static let beige = Theme.ColorToken.milk
    }
}

// MARK: - Section Card

struct CreateAdSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CreateAdUI.Spacing.m) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .padding(CreateAdUI.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: CreateAdUI.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CreateAdUI.Radius.card, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Structured Controls

struct CreateAdChoiceChip: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var isSelected: Bool
    var accent: Color = Theme.ColorToken.turquoise
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: subtitle == nil || compact ? .center : .top, spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: compact ? 13 : 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : accent)
                }

                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text(title)
                        .font(.system(size: compact ? 13 : 15, weight: .bold))
                        .multilineTextAlignment(.leading)

                    if let subtitle, !compact {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(isSelected ? Color.white.opacity(0.84) : Theme.ColorToken.textSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.white : Theme.ColorToken.textPrimary)
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                    .fill(isSelected ? accent : Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                    .stroke(isSelected ? accent : accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CreateAdToggleTile: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    @Binding var isOn: Bool
    var accent: Color = Theme.ColorToken.turquoise

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? accent : Theme.ColorToken.textSecondary)
                        .frame(width: 18)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isOn ? accent : Theme.ColorToken.textSecondary.opacity(0.55))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isOn ? accent.opacity(0.10) : Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isOn ? accent.opacity(0.35) : accent.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CreateAdInfoTag: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.ColorToken.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            Capsule()
                .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
        )
    }
}

struct CreateAdSummaryCard: View {
    let title: String
    let tags: [String]
    let route: String
    let whenText: String
    let budgetText: String
    var accent: Color = Theme.ColorToken.turquoise

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Итог объявления")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ColorToken.textSecondary)

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ColorToken.textPrimary)
            }

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            CreateAdInfoTag(title: tag)
                        }
                    }
                }
            }

            VStack(spacing: 10) {
                summaryRow(title: "Маршрут", value: route)
                summaryRow(title: "Когда", value: whenText)
                summaryRow(title: "Оплата", value: budgetText)
            }
        }
        .padding(CreateAdUI.Spacing.l)
        .background(
            LinearGradient(
                colors: [
                    accent.opacity(0.18),
                    Color.white.opacity(0.84),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: CreateAdUI.Radius.card, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CreateAdUI.Radius.card, style: .continuous))
        .softCardShadow()
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CreateAdStickyMiniSummary: View {
    let title: String
    let actionText: String
    let objectText: String
    let routeText: String
    let whenText: String
    let priceText: String
    @Binding var isExpanded: Bool
    var accent: Color = Theme.ColorToken.turquoise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.ColorToken.textPrimary)
                            .lineLimit(isExpanded ? 2 : 1)

                        HStack(spacing: 8) {
                            CreateAdInfoTag(title: actionText)
                            CreateAdInfoTag(title: objectText)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    miniRow(title: "Маршрут", value: routeText)
                    miniRow(title: "Когда", value: whenText)
                    miniRow(title: "Цена", value: priceText)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
        .softCardShadow()
    }

    private func miniRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CreateAdRecommendedPriceView: View {
    let title: String
    let subtitle: String
    var accent: Color = Theme.ColorToken.turquoise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Рекомендуемая цена")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ColorToken.textSecondary)

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.ColorToken.textPrimary)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ColorToken.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}

struct CreateAdReadinessCard: View {
    let title: String
    let issues: [String]
    var accent: Color = Theme.ColorToken.turquoise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold))

            ForEach(Array(issues.prefix(6)), id: \.self) { issue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(accent)
                        .padding(.top, 6)

                    Text(issue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
    }
}

// MARK: - Fields

struct CreateAdTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var mark: CreateAdDraft.DraftModerationMark? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let mark {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(mark.severity.color)
                }
            }

            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.sentences)
                .font(.system(size: 16, weight: .semibold))
                .padding(.vertical, 10)

            Divider().opacity(0.35)
        }
    }
}

struct CreateAdValueField: View {
    let label: String
    let placeholder: String
    let trailing: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .semibold))
                    .onChange(of: text) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue {
                            text = digits
                        }
                    }

                Spacer(minLength: 0)

                Text(trailing)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)

            Divider().opacity(0.35)
        }
    }
}

struct CreateAdBudgetRangeField: View {
    let label: String
    var accent: Color = Theme.ColorToken.turquoise
    var minPlaceholder: String = "0"
    var maxPlaceholder: String = "0"
    @Binding var minText: String
    @Binding var maxText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            budgetRow(title: "От", placeholder: minPlaceholder, text: $minText)
            budgetRow(title: "До", placeholder: maxPlaceholder, text: $maxText)

            Divider().opacity(0.35)
        }
    }

    private func budgetRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 26, alignment: .leading)

            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.leading)
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(accent.opacity(0.22), lineWidth: 1)
                )
                .onChange(of: text.wrappedValue) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits != newValue {
                        text.wrappedValue = digits
                    }
                }

            Text("₽")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct CreateAdToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 6)
    }
}

struct CreateAdTextArea: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var mark: CreateAdDraft.DraftModerationMark? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let mark {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(mark.severity.color)
                }
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .padding(.top, 10)
                        .padding(.leading, 4)
                }
                TextEditor(text: $text)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 16, weight: .regular))
            }
            .padding(.vertical, 6)

            Divider().opacity(0.35)
        }
    }
}

// MARK: - Bottom Button

struct CreateAdBottomButton: View {
    let title: String
    let accent: Color
    var floating: Bool = true
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isEnabled ? accent : accent.opacity(0.45))
                )
                .shadow(color: accent.opacity(isEnabled ? 0.25 : 0.08), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, floating ? 20 : 0)
        .padding(.vertical, floating ? 12 : 0)
        .background {
            if floating {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}
