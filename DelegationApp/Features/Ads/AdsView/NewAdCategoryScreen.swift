//
//  NewAdCategoryScreen.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 24.11.2025.
//

//
//  NewAdCategoryScreen.swift
//  iCuno test
//
//  Экран "Новое объявление" (выбор категории).
//

import SwiftUI

/// Экран выбора категории для нового объявления.
struct NewAdCategoryScreen: View {
    @Environment(\.dismiss) private var dismiss

    private let categories: [AdCategory] = [
        .init(title: "Доставка по пути", systemImage: "car.fill"),
        .init(title: "Мелкие поручения", systemImage: "building.2.fill"),
        .init(title: "Помощь нуждающимся", systemImage: "briefcase.fill"),
        .init(title: "Помощь руками", systemImage: "scissors"),
        .init(title: "Специализиранные услуги", systemImage: "swift")
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                categoriesList
                Spacer()
            }
        }
    }

    // MARK: - Подвиды

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.gray)
                        .padding(8)
                }

                Spacer()
            }

            Text("Новое объявление")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
    }

    private var categoriesList: some View {
        VStack(spacing: 0) {
            ForEach(categories) { category in
                Button {
                    // Пока просто закрываем экран.
                    // Потом здесь можно будет открывать форму создания объявления.
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 20))
                            .frame(width: 28, height: 28)
                            .foregroundStyle(Color.white)

                        Text(category.title)
                            .font(.system(size: 17))
                            .foregroundStyle(Color.gray)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.gray)
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(Color.gray.opacity(0.6))
                    .padding(.leading, Theme.Spacing.l + 28 + 12)
            }
        }
    }
}

private struct AdCategory: Identifiable {
    let id: UUID = .init()
    let title: String
    let systemImage: String
}

//#Preview("NewAdCategoryScreen") {
//    NewAdCategoryScreen()
//        .preferredColorScheme(.dark)
//}
