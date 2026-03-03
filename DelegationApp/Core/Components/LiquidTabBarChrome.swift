import SwiftUI

enum AppChrome {
    enum LiquidTabBar {
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 8
        static let barHeight: CGFloat = 74
        static let contentClearance: CGFloat = 96
    }
}

final class LiquidTabBarVisibilityStore: ObservableObject {
    @Published private(set) var hiddenReasons: Set<String> = []

    var isHidden: Bool {
        !hiddenReasons.isEmpty
    }

    func setHidden(_ hidden: Bool, reason: String) {
        if hidden {
            hiddenReasons.insert(reason)
        } else {
            hiddenReasons.remove(reason)
        }
    }
}

private struct LiquidTabBarVisibilityStoreKey: EnvironmentKey {
    static let defaultValue: LiquidTabBarVisibilityStore? = nil
}

extension EnvironmentValues {
    var liquidTabBarVisibilityStore: LiquidTabBarVisibilityStore? {
        get { self[LiquidTabBarVisibilityStoreKey.self] }
        set { self[LiquidTabBarVisibilityStoreKey.self] = newValue }
    }
}

private struct LiquidTabBarHiddenModifier: ViewModifier {
    @Environment(\.liquidTabBarVisibilityStore) private var tabBarVisibility
    let reason: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                tabBarVisibility?.setHidden(true, reason: reason)
            }
            .onDisappear {
                tabBarVisibility?.setHidden(false, reason: reason)
            }
    }
}

extension View {
    func hidesLiquidTabBar(reason: String) -> some View {
        modifier(LiquidTabBarHiddenModifier(reason: reason))
    }
}
