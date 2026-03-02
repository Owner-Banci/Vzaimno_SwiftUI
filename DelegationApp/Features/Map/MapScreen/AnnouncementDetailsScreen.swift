//
//  AnnouncementDetailsScreen.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 27.02.2026.
//

import SwiftUI

struct AnnouncementDetailsScreen: View {
    let item: AnnouncementDTO
    @ObservedObject var vm: MyAdsViewModel

    @State private var showCreateFromThis: Bool = false
    @State private var prefilledDraft: CreateAdDraft?

    private var currentItem: AnnouncementDTO {
        vm.item(with: item.id) ?? item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if currentItem.previewImageURL != nil {
                    AnnouncementGalleryView(announcement: currentItem, height: 240, cornerRadius: 22)
                }

                header
                moderationBlock
                detailsBlock

                if currentItem.normalizedStatus == "needs_fix" {
                    Button {
                        Task { await createNewFromThis() }
                    } label: {
                        Text("Новое объявление")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Theme.ColorToken.turquoise)
                            )
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(16)
        }
        .navigationTitle("Детали")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateFromThis) {
            if let draft = prefilledDraft {
                CreateAdFlowHost(
                    service: vm.service,
                    session: vm.session,
                    prefilledDraft: draft
                ) { created in
                    vm.insertOptimistic(created)
                } onPublishCompletion: { localID, result in
                    vm.resolveSubmission(localID: localID, result: result)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentItem.title)
                .font(.system(size: 22, weight: .bold))

            HStack(spacing: 8) {
                StatusBadge(status: currentItem.normalizedStatus)
                if currentItem.hasModerationIssues {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(currentItem.maxReasonSeverity.color)
                }
            }
        }
    }

    private var moderationBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Статус и причина")
                .font(.system(size: 16, weight: .bold))

            if let msg = currentItem.decisionMessage, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let reasons = currentItem.moderationPayload?.reasons, !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(reasons) { reason in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(reason.severity.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fieldTitle(reason.field))
                                    .font(.system(size: 14, weight: .semibold))
                                Text(reason.details)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.6)))
        .softCardShadow()
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Данные")
                .font(.system(size: 16, weight: .bold))

            fieldRow("Название", value: currentItem.title, severity: currentItem.severity(for: "title"))

            if let notes = currentItem.data["notes"]?.stringValue, !notes.isEmpty {
                fieldRow("Описание", value: notes, severity: currentItem.severity(for: "notes"))
            }

            if currentItem.category == "delivery" {
                fieldRow(
                    "Адрес забора",
                    value: currentItem.data["pickup_address"]?.stringValue ?? "—",
                    severity: currentItem.severity(for: "pickup_address")
                )
                fieldRow(
                    "Адрес доставки",
                    value: currentItem.data["dropoff_address"]?.stringValue ?? "—",
                    severity: currentItem.severity(for: "dropoff_address")
                )
            } else if currentItem.category == "help" {
                fieldRow(
                    "Адрес",
                    value: currentItem.data["address"]?.stringValue ?? "—",
                    severity: currentItem.severity(for: "address")
                )
            }

            fieldRow(
                "Фото",
                value: currentItem.imageURLs.isEmpty ? "Не прикреплено" : "Прикреплено: \(currentItem.imageURLs.count)",
                severity: currentItem.severity(for: "media")
            )
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.6)))
        .softCardShadow()
    }

    private func fieldRow(_ title: String, value: String, severity: ModerationSeverity) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if severity != .none {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(severity.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
    }

    private func fieldTitle(_ field: String) -> String {
        switch field {
        case "title": return "Название"
        case "notes": return "Описание"
        case "pickup_address": return "Адрес забора"
        case "dropoff_address": return "Адрес доставки"
        case "address": return "Адрес"
        case "media": return "Фото"
        default: return field
        }
    }

    private func createNewFromThis() async {
        await vm.archive(currentItem.id)

        let draft = CreateAdDraft.prefilled(from: currentItem)
        draft.applyModerationMarks(from: currentItem)
        prefilledDraft = draft
        showCreateFromThis = true
    }
}
