import SwiftUI

struct NewAdCategoryScreen: View {
    @ObservedObject var draft: CreateAdDraft
    let onClose: () -> Void
    let onFinish: (AnnouncementDTO) -> Void

    private let deliveryAccent = Theme.ColorToken.turquoise
    private let helpAccent = CreateAdUI.Palette.beige

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(spacing: 14) {
                    NavigationLink {
                        NewDeliveryAdFormScreen(
                            draft: draft,
                            accent: deliveryAccent,
                            onFinish: onFinish
                        )
                        .onAppear { draft.category = .delivery }
                    } label: {
                        CategoryCard(
                            title: CreateAdDraft.Category.delivery.title,
                            subtitle: CreateAdDraft.Category.delivery.subtitle,
                            systemImage: "truck.box.badge.clock",
                            background: deliveryAccent.opacity(0.22),
                            border: deliveryAccent.opacity(0.28)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NewHelpAdFormScreen(
                            draft: draft,
                            accent: deliveryAccent,
                            onFinish: onFinish
                        )
                        .onAppear { draft.category = .help }
                    } label: {
                        CategoryCard(
                            title: CreateAdDraft.Category.help.title,
                            subtitle: CreateAdDraft.Category.help.subtitle,
                            systemImage: "hands.sparkles",
                            background: helpAccent,
                            border: helpAccent.opacity(0.95)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .navigationTitle("Новое объявление")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.ColorToken.turquoise)
                        .padding(6)
                }
                .accessibilityLabel("Закрыть")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Новое объявление")
                .font(.system(size: 34, weight: .bold))

            Text("С чем вам нужна помощь?")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let background: Color
    let border: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(height: 42, alignment: .topLeading)

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.75))
                .padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 208, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
    }
}
