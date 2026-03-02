//
//  AdMediaPickerSection.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 27.02.2026.
//

import SwiftUI
import PhotosUI

struct AdMediaPickerSection: View {
    @ObservedObject var draft: CreateAdDraft
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 3,
                matching: .images
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(draft.mediaImages.isEmpty ? "Добавить фото (до 3)" : "Изменить фото")
                }
                .font(.system(size: 15, weight: .semibold))
            }

            if !draft.mediaImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(draft.mediaImages.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 86, height: 86)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                Button {
                                    draft.removeMedia(at: idx)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .padding(6)
                            }
                        }
                    }
                }
            } else {
                Text("Фото проверяются на сервере. Если спорно — объявление уйдёт в черновики.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: pickerItems) { _, newItems in
            Task {
                var datas: [Data] = []
                for item in newItems {
                    if let d = try? await item.loadTransferable(type: Data.self) {
                        datas.append(d)
                    }
                }
                await MainActor.run {
                    draft.setMediaFromPicker(datas: datas)
                }
            }
        }
    }
}
