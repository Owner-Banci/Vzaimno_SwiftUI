//
//  AdsScreen.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 24.11.2025.
//

//
//  MyAdsScreen.swift
//  iCuno test
//
//  Экран "Мои объявления" по мотивам Авито.
//

import SwiftUI

/// Экран "Мои объявления".
struct MyAdsScreen: View {
    @State private var selectedFilter: AdsFilter = .waiting
    @State private var showNewAdSheet = false

    // Моки для примера. Потом можно заменить данными сервиса.
    private let ads: [AdItem] = [
        .init(
            title: "Помощь с сопрожением незрячей",
            priceDescription: "от 300 ₽ за услугу",
            isExpired: true,
            views: 58,
            responses: 1,
            favorites: 3
        )
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    summarySection
                    filtersSection
//                    promoSection
                    expiredSection
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)
                // запас места под нижнюю кнопку
            }


            newAdButton
                .padding(.bottom, 45)
        }
        .sheet(isPresented: $showNewAdSheet) {
            NewAdCategoryScreen()
        }
        .navigationTitle("Мои объявления")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Подсекции

    /// Зеленая и синяя карточки сверху экрана.
    private var summarySection: some View {
        HStack(spacing: Theme.Spacing.m) {
            SmallSummaryCard(
                title: "Скидки и акции",
                subtitle: "настройте для исполнителей",
                gradient: LinearGradient(
                    colors: [Color.hex("#B6FAC3"), Color.hex("#84A4FA")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            SmallSummaryCard(
                title: "29 990 ₽",
                subtitle: "заработано",
                gradient: LinearGradient(
                    colors: [Color.hex("#0D47A1"), Color.hex("#1976D2")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    /// Вкладки "Ждут действий / Активные / Черновики".
    private var filtersSection: some View {
        HStack(spacing: Theme.Spacing.l) {
            ForEach(AdsFilter.allCases) { filter in
                VStack(spacing: 4) {
                    Text(filter.titleWithCount)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(filter == selectedFilter ? Theme.ColorToken.turquoise : Color.gray)

                    Rectangle()
                        .fill(filter == selectedFilter ? Theme.ColorToken.turquoise : Color.clear)
                        .frame(height: 3)
                        .cornerRadius(1.5)
                }
                .onTapGesture {
                    selectedFilter = filter
                }
            }
        }
        .padding(.top, Theme.Spacing.l)
    }

//    /// Синяя промо-карточка "До 25% больше продаж".
//    private var promoSection: some View {
//        RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
//            .fill(
//                LinearGradient(
//                    colors: [Color.hex("#0046A5"), Color.hex("#0059D6")],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//            )
//            .overlay(alignment: .leading) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("До 25% больше продаж")
//                        .font(.system(size: 16, weight: .semibold))
//                    Text("Предложите покупателям скидку за покупку нескольких товаров")
//                        .font(.system(size: 13))
//                        .fixedSize(horizontal: false, vertical: true)
//                }
//                .foregroundStyle(Color.gray)
//                .padding(16)
//            }
//            .frame(maxWidth: .infinity)
//    }

    /// Секция с заголовком "Истёк срок размещения" и карточками объявлений.
    private var expiredSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
//            Text("Истёк срок размещения")
//                .font(.system(size: 15, weight: .semibold))
//                .foregroundStyle(Color.white)

            ForEach(ads.filter { $0.isExpired }) { ad in
                AdCardView(ad: ad)
            }
        }
        .padding(.top, Theme.Spacing.l)
    }

    /// Нижняя большая кнопка "Разместить объявление".
    private var newAdButton: some View {
        Button {
            showNewAdSheet = true
        } label: {
            Text("Разместить объявление")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.7))
                )
                .padding(.horizontal, Theme.Spacing.l)

        }
        .buttonStyle(.plain)
    }
}

// MARK: - Вспомогательные типы и вьюшки

/// Тип вкладки в верхнем сегменте.
private enum AdsFilter: CaseIterable, Identifiable {
    case waiting
    case active
    case drafts

    var id: Self { self }

    var title: String {
        switch self {
        case .waiting: return "Ждут действий"
        case .active:  return "Активные"
        case .drafts:  return "Черновики"
        }
    }

    /// Для примера захардкожены те же цифры, что и на скрине.
    var count: Int {
        switch self {
        case .waiting: return 1
        case .active:  return 1
        case .drafts:  return 0
        }
    }

    var titleWithCount: String {
        "\(title) \(count)"
    }
}

/// Маленькая карточка вверху ("Скидки и акции" / "29 990 ₽...").
private struct SmallSummaryCard: View {
    let title: String
    let subtitle: String
    let gradient: LinearGradient

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                .fill(gradient)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.8))
            }
            .foregroundStyle(Color.black)
            .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
    }
}

/// Карточка одного объявления.
private struct AdCardView: View {
    let ad: AdItem

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 96, height: 72)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.white.opacity(0.7))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(ad.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gray)
                        .lineLimit(2)

                    Text(ad.priceDescription)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.gray)

                    Text("Истёк срок размещения")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.gray)
                }

                Spacer()

                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.gray.opacity(0.8))
            }

            HStack(spacing: 12) {
                IconCounterView(systemName: "eye", text: "\(ad.views)")
                IconCounterView(systemName: "person", text: "\(ad.responses)")
                IconCounterView(systemName: "heart", text: "\(ad.favorites)")
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.gray)
            .padding(.vertical, 10)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(15)
//        .background(
//            RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
//                .fill(Color.white.opacity(0.5))
//        )
    }
}

/// Статистика "глазик + число", "человечек + число" и т.п.
private struct IconCounterView: View {
    let systemName: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
            Text(text)
        }
    }
}

//#Preview("MyAdsScreen") {
//    NavigationStack {
//        MyAdsScreen()
//    }
//    .preferredColorScheme(.dark)
//}
