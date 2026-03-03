import Foundation

@MainActor
final class MyAdsViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorText: String?
    @Published var toastMessage: String?
    @Published private(set) var items: [AnnouncementDTO] = []

    let service: AnnouncementService
    let session: SessionStore

    private var serverItems: [AnnouncementDTO] = []
    private var optimisticItems: [String: AnnouncementDTO] = [:]
    private var autoRefreshTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init(service: AnnouncementService, session: SessionStore) {
        self.service = service
        self.session = session
    }

    deinit {
        autoRefreshTask?.cancel()
        toastTask?.cancel()
    }

    func reload(showLoader: Bool = true) async {
        guard let token = session.token else {
            errorText = "Нет токена сессии"
            return
        }

        if showLoader {
            isLoading = true
        }
        defer {
            if showLoader {
                isLoading = false
            }
        }

        do {
            serverItems = try await service.myAnnouncements(token: token)
            rebuildItems()
            updateAutoRefreshIfNeeded()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func archive(_ announcementId: String) async {
        if removeOptimisticIfNeeded(announcementId) {
            return
        }

        guard let token = session.token else { return }
        do {
            _ = try await service.archiveAnnouncement(token: token, announcementId: announcementId)
            await reload(showLoader: false)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func delete(_ announcementId: String) async {
        if removeOptimisticIfNeeded(announcementId) {
            return
        }

        guard let token = session.token else { return }
        do {
            _ = try await service.deleteAnnouncement(token: token, announcementId: announcementId)
            serverItems.removeAll { $0.id == announcementId }
            rebuildItems()
            updateAutoRefreshIfNeeded()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func insertOptimistic(_ announcement: AnnouncementDTO) {
        optimisticItems[announcement.id] = announcement
        rebuildItems()
        showToast("Отправлено на проверку")
        updateAutoRefreshIfNeeded()
    }

    func resolveSubmission(localID: String, result: Result<AnnouncementDTO, Error>) {
        let optimistic = optimisticItems.removeValue(forKey: localID)

        switch result {
        case .success(let announcement):
            upsertServerItem(mergePreviewIfNeeded(from: optimistic, into: announcement))
        case .failure(let error):
            errorText = "Не удалось опубликовать объявление: \(error.localizedDescription)"
        }

        rebuildItems()
        updateAutoRefreshIfNeeded()
    }

    func item(with id: String) -> AnnouncementDTO? {
        items.first {
            $0.id == id || $0.data["client_submission_id"]?.stringValue == id
        }
    }

    // MARK: - Filters

    var activeCount: Int {
        items.filter { $0.isActiveStatus }.count
    }

    var actionsCount: Int {
        items.filter { $0.isActionsStatus }.count
    }

    var archivedCount: Int {
        items.filter { $0.isArchivedStatus }.count
    }

    func filteredItems(for filter: AdsFilter) -> [AnnouncementDTO] {
        switch filter {
        case .active:
            return items.filter { $0.isActiveStatus }
        case .actions:
            return items.filter { $0.isActionsStatus }
        case .archived:
            return items.filter { $0.isArchivedStatus }
        }
    }

    // MARK: - Private

    private func removeOptimisticIfNeeded(_ announcementId: String) -> Bool {
        guard optimisticItems.removeValue(forKey: announcementId) != nil else {
            return false
        }

        rebuildItems()
        updateAutoRefreshIfNeeded()
        return true
    }

    private func upsertServerItem(_ announcement: AnnouncementDTO) {
        if let index = serverItems.firstIndex(where: { $0.id == announcement.id }) {
            serverItems[index] = announcement
        } else {
            serverItems.append(announcement)
        }
    }

    private func mergePreviewIfNeeded(
        from optimistic: AnnouncementDTO?,
        into announcement: AnnouncementDTO
    ) -> AnnouncementDTO {
        guard let optimistic else {
            return announcement
        }

        var data = announcement.data
        if data["client_submission_id"] == nil {
            data["client_submission_id"] = .string(optimistic.id)
        }

        if announcement.previewImageURL == nil, let optimisticMedia = optimistic.data["media"] {
            data["media"] = optimisticMedia
        }

        return AnnouncementDTO(
            id: announcement.id,
            user_id: announcement.user_id,
            category: announcement.category,
            title: announcement.title,
            status: announcement.status,
            data: data,
            created_at: announcement.created_at,
            media: announcement.media
        )
    }

    private func rebuildItems() {
        let combined = serverItems + Array(optimisticItems.values)
        items = combined.sorted { lhs, rhs in
            if lhs.createdAtDate == rhs.createdAtDate {
                return lhs.id > rhs.id
            }
            return lhs.createdAtDate > rhs.createdAtDate
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message

        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.toastMessage = nil
            }
        }
    }

    // MARK: - Auto refresh pending_review

    private func updateAutoRefreshIfNeeded() {
        let hasPending = items.contains { $0.needsStatusPolling }

        if hasPending {
            guard autoRefreshTask == nil else { return }

            autoRefreshTask = Task { [weak self] in
                guard let self else { return }

                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    guard !Task.isCancelled else { break }

                    await self.reload(showLoader: false)
                    if !self.items.contains(where: { $0.needsStatusPolling }) {
                        break
                    }
                }

                self.autoRefreshTask = nil
            }
        } else {
            autoRefreshTask?.cancel()
            autoRefreshTask = nil
        }
    }
}

enum AdsFilter: String, CaseIterable, Identifiable {
    case active = "Активные"
    case actions = "Ждут действий"
    case archived = "Архив"

    var id: String { rawValue }
}
