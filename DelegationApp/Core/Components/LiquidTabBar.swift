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
