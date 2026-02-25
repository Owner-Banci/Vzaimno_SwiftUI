//
//  CreateAdFlowHost.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import SwiftUI

struct CreateAdFlowHost: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var draft = CreateAdDraft()
    @StateObject private var vm: CreateAdFlowViewModel

    let onCreated: (AnnouncementDTO) -> Void

    init(
        service: AnnouncementService,
        session: SessionStore,
        onCreated: @escaping (AnnouncementDTO) -> Void
    ) {
        _vm = StateObject(wrappedValue: CreateAdFlowViewModel(service: service, session: session))
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            NewAdCategoryScreen(
                draft: draft,
                onClose: { dismiss() },
                onFinish: { created in
                    onCreated(created)
                    dismiss()
                }
            )
        }
        .environmentObject(vm)
        .background(Theme.ColorToken.milk.ignoresSafeArea())
    }
}
