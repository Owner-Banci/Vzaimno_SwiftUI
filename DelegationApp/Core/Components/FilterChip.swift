import SwiftUI

/// Универсальный чип-фильтр.
/// Поддерживает два режима:
/// 1) Binding<Bool> — чип сам переключает состояние.
/// 2) Bool + action — состояние вычисляется снаружи, чип только вызывает action.
struct FilterChip: View {
    let title: String

    // Внутри всегда есть Binding, но во "внешнем" режиме он будет .constant(...)
    @Binding private var isSelected: Bool

    // Нужно ли самому делать toggle()
    private let togglesSelection: Bool

    // Доп. действие при тапе (например, выбрать фильтр)
    private let action: (() -> Void)?

    // MARK: - Init (Binding mode)
    init(
        title: String,
        isSelected: Binding<Bool>,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self._isSelected = isSelected
        self.togglesSelection = true
        self.action = action
    }

    // MARK: - Init (Computed Bool mode)
    init(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self._isSelected = .constant(isSelected)
        self.togglesSelection = false
        self.action = action
    }

    var body: some View {
        Button {
            if togglesSelection {
                isSelected.toggle()
            }
            action?()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.ColorToken.turquoise : Color.white.opacity(0.7))
                )
                .overlay(
                    Capsule()
                        .stroke(Theme.ColorToken.turquoise.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
