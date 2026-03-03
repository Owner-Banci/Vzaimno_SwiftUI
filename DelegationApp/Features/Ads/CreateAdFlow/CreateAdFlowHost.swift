import SwiftUI

struct CreateAdFlowHost: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var draft: CreateAdDraft
    @StateObject private var vm: CreateAdFlowViewModel

    let onCreated: (AnnouncementDTO) -> Void

    init(
        service: AnnouncementService,
        session: SessionStore,
        searchService: AddressSearchService = AddressSearchService(),
        prefilledDraft: CreateAdDraft? = nil,
        onCreated: @escaping (AnnouncementDTO) -> Void,
        onPublishCompletion: @escaping AnnouncementPublishCompletion = { _, _ in }
    ) {
        _draft = StateObject(wrappedValue: prefilledDraft ?? CreateAdDraft())
        _vm = StateObject(
            wrappedValue: CreateAdFlowViewModel(
                service: service,
                session: session,
                searchService: searchService,
                publishCompletion: onPublishCompletion
            )
        )
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
