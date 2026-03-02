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
                        .fill(accent)
                )
                .shadow(color: accent.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
