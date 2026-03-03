//
//  CreateAdBackButton.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import SwiftUI

/// Единая кнопка "Назад" для create-flow, чтобы не дублировать код по экранам.
struct CreateAdBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.65)))
        }
    }
}
