import SwiftUI

struct NewAdCategoryScreen: View {
    @ObservedObject var draft: CreateAdDraft
    let onClose: () -> Void
    let onFinish: (AnnouncementDTO) -> Void

    private let accent = Theme.ColorToken.turquoise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(spacing: 16) {
                    NavigationLink {
                        NewDeliveryAdFormScreen(
                            draft: draft,
                            accent: accent,
                            onFinish: onFinish
                        )
                        .onAppear { draft.category = .delivery }
                    } label: {
                        CategoryCard(
                            title: CreateAdDraft.Category.delivery.title,
                            subtitle: CreateAdDraft.Category.delivery.subtitle,
                            systemImage: "shippingbox.fill",
                            tint: accent
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NewHelpAdFormScreen(
                            draft: draft,
                            accent: accent,
                            onFinish: onFinish
                        )
                        .onAppear { draft.category = .help }
                    } label: {
                        CategoryCard(
                            title: CreateAdDraft.Category.help.title,
                            subtitle: CreateAdDraft.Category.help.subtitle,
                            systemImage: "hands.sparkles.fill",
                            tint: accent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.65)))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Новое объявление")
                .font(.system(size: 28, weight: .bold))
            Text("Выберите тип объявления")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
