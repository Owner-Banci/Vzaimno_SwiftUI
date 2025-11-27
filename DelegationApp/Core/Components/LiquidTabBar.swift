////
////  LiquidTabBar.swift
////  iCuno test
////
////  Created by maftuna murtazaeva on 26.11.2025.
////
//
//import SwiftUI
//
///// Прозрачный TabBar с «Liquid Glass»-индикатором (плавно переезжает между иконками).
//struct LiquidTabBar: View {
//    @Binding var selection: AppTab
//    var badges: [AppTab: Int] = [:]
//
//    @Namespace private var bubbleNS
//
//    var body: some View {
//        HStack(spacing: 0) {
//            ForEach(AppTab.allCases) { tab in
//                tabButton(for: tab)
//            }
//        }
//        .padding(.horizontal, 10)
//        .padding(.vertical, 10)
//        .background(
//            RoundedRectangle(cornerRadius: 24, style: .continuous)
//                .fill(.ultraThinMaterial) // «стекло»
//                .overlay(
//                    // лёгкий «контур» для стекла
//                    RoundedRectangle(cornerRadius: 24)
//                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
//                )
//                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
//        )
//        // плавность переезда «капли» между иконками
//        .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.2), value: selection)
//        .accessibilityElement(children: .contain)
//    }
//
//    // MARK: - Кнопка вкладки
//    private func tabButton(for tab: AppTab) -> some View {
//        Button {
//            if selection != tab {
//                selection = tab
//                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
//            }
//        } label: {
//            ZStack {
//                // «Жидкая капля» под выбранной иконкой
//                if selection == tab {
//                    Circle()
//                        .fill(.ultraThinMaterial)
//                        .overlay(
//                            Circle()
//                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
//                        )
//                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
//                        .matchedGeometryEffect(id: "LIQUID_BUBBLE", in: bubbleNS)
//                        .frame(width: 75, height: 55)
//                        .transition(.opacity)
//                }
//
//                VStack(spacing: 6) {
//                    Image(systemName: tab.iconName(selected: selection == tab))
//                        .font(.system(size: 20, weight: .semibold))
//                        .scaleEffect(selection == tab ? 1.06 : 1.0)
//                        .foregroundStyle(selection == tab ? Theme.ColorToken.turquoise : Theme.ColorToken.textSecondary)
//                        .frame(height: 20)
//
//                    Text(tab.title)
//                        .font(.system(size: 12, weight: .semibold))
//                        .foregroundStyle(selection == tab ? Theme.ColorToken.turquoise : Theme.ColorToken.textSecondary)
//                        .opacity(0.95)
//                }
//                .frame(maxWidth: 200, minHeight: 48)
//            }
//            .contentShape(Rectangle())
//        }
//        .buttonStyle(.plain)
//        .frame(maxWidth: .infinity)
//        .overlay(alignment: .topTrailing) {
//            if let count = badges[tab], count > 0 {
//                Text("\(count)")
//                    .font(.system(size: 11, weight: .bold))
//                    .padding(6)
//                    .background(Circle().fill(Color.red))
//                    .foregroundStyle(.white)
//                    .offset(x: 12, y: -6)
//                    .transition(.scale)
//            }
//        }
//        .accessibilityLabel(tab.title)
//    }
//}

import SwiftUI

/// Прозрачный TabBar в стиле iOS 26 / Telegram
/// с «жидким» индикатором, который плавно переезжает между иконками.
struct LiquidTabBar: View {
    @Binding var selection: AppTab
    var badges: [AppTab: Int] = [:]

    @Namespace private var indicatorNamespace

    // Размеры — их теперь легко править
    private let barCornerRadius: CGFloat = 26
    private let barHeight: CGFloat = 74
    private let bubbleSize: CGFloat = 54

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: barHeight)
        .background(
            RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial) // стекло
                .overlay(
                    RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.10),
                        radius: 22,
                        x: 0,
                        y: 10)
        )
        // Плавный переезд «капли» между иконками
        .animation(
            .spring(response: 0.45,
                    dampingFraction: 0.85,
                    blendDuration: 0.25),
            value: selection
        )
    }

    // MARK: - Одна кнопка таба

    private func tabButton(for tab: AppTab) -> some View {
        Button {
            if selection != tab {
                selection = tab
            }
        } label: {
            ZStack {
                // «Liquid Glass» пузырёк под выбранной иконкой
                if selection == tab {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.20),
                                radius: 14,
                                x: 0,
                                y: 8)
                        .matchedGeometryEffect(id: "LIQUID_INDICATOR",
                                               in: indicatorNamespace)
                        .frame(width: bubbleSize, height: bubbleSize)
                        .transition(.opacity)
                }

                VStack(spacing: 4) {
                    Image(systemName: tab.iconName(selected: selection == tab))
                        .font(.system(size: 18, weight: .semibold)) // иконка немного меньше
                        .foregroundColor(
                            selection == tab
                            ? Theme.ColorToken.turquoise
                            : Theme.ColorToken.textSecondary
                        )
                        .scaleEffect(selection == tab ? 1.08 : 1.0)
                        .frame(height: 20)

                    Text(tab.title)
                        .font(.system(size: 11, weight: .semibold)) // текст поменьше
                        .foregroundColor(
                            selection == tab
                            ? Theme.ColorToken.turquoise
                            : Theme.ColorToken.textSecondary
                        )
                        .lineLimit(1)              // всегда в одну строку
                        .minimumScaleFactor(0.7)   // «Объявления» сжимается, но не переносится
                }
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            // Красный бейдж (например, на профиле «2»)
            if let count = badges[tab], count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(5)
                    .background(
                        Circle()
                            .fill(Color.red)
                    )
                    .foregroundColor(.white)
                    .offset(x: 8, y: -10)
            }
        }
    }
}
