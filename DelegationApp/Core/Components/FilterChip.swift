//
//  FilterChip.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 07.11.2025.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    @Binding var isSelected: Bool
    
    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 8) {
                if isSelected { Image(systemName: "checkmark") }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                    .fill(isSelected ? Theme.ColorToken.turquoise : Theme.ColorToken.milk)
            )
            .foregroundStyle(isSelected ? Color.white : Theme.ColorToken.textPrimary)
            .softCardShadow()
        }
        .buttonStyle(.plain)
    }
}
