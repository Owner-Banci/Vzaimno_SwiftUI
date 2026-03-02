import Foundation

typealias AnnouncementPublishCompletion = @MainActor (_ localID: String, _ result: Result<AnnouncementDTO, Error>) -> Void

@MainActor
final class CreateAdFlowViewModel: ObservableObject {
    @Published var isSubmitting: Bool = false
    @Published var errorText: String?

    private let service: AnnouncementService
    private let session: SessionStore
    private let searchService: AddressSearchService
    private let publishCompletion: AnnouncementPublishCompletion

    init(
        service: AnnouncementService,
        session: SessionStore,
        searchService: AddressSearchService = AddressSearchService(),
        publishCompletion: @escaping AnnouncementPublishCompletion = { _, _ in }
    ) {
        self.service = service
        self.session = session
        self.searchService = searchService
        self.publishCompletion = publishCompletion
    }

    func submit(draft: CreateAdDraft) async -> AnnouncementDTO? {
        errorText = nil

        guard let token = session.token else {
            errorText = "Нет токена сессии"
            return nil
        }

        if let validationError = await draft.validateForSubmit(searchService: searchService) {
            errorText = validationError
            return nil
        }

        let request = draft.toCreateRequest(status: "pending_review")
        let localID = "local-\(UUID().uuidString)"
        let optimisticAnnouncement = makeOptimisticAnnouncement(
            localID: localID,
            request: request,
            draft: draft
        )
//        let token = token
        let service = service
        let publishCompletion = publishCompletion
        let mediaData = draft.mediaJPEGData

        isSubmitting = true
        Task {
            defer {
                Task { @MainActor [weak self] in
                    self?.isSubmitting = false
                }
            }

            do {
                var created = try await service.createAnnouncement(token: token, request: request)

                if !mediaData.isEmpty {
                    do {
                        created = try await service.uploadAnnouncementMedia(
                            token: token,
                            announcementId: created.id,
                            images: mediaData
                        )
                    } catch {
                        await MainActor.run { [weak self] in
                            self?.errorText = "Объявление создано, но фото пока не загрузились: \(error.localizedDescription)"
                        }
                    }
                }

                await publishCompletion(localID, .success(created))
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorText = error.localizedDescription
                }
                await publishCompletion(localID, .failure(error))
            }
        }

        return optimisticAnnouncement
    }

    private func makeOptimisticAnnouncement(
        localID: String,
        request: CreateAnnouncementRequest,
        draft: CreateAdDraft
    ) -> AnnouncementDTO {
        var data = request.data
        data["client_submission_id"] = .string(localID)
        let previewMedia = draft.mediaJPEGData.prefix(3).compactMap(Self.makeTemporaryMediaJSON(from:))
        if !previewMedia.isEmpty {
            data["media"] = .array(previewMedia)
        }

        return AnnouncementDTO(
            id: localID,
            user_id: session.me?.id ?? "local",
            category: request.category,
            title: request.title,
            status: "pending_review",
            data: data,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
    }

    private static func makeTemporaryMediaJSON(from data: Data) -> JSONValue? {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("announcement-preview-\(UUID().uuidString).jpg")

        do {
            try data.write(to: fileURL, options: .atomic)
            return .object(["url": .string(fileURL.absoluteString)])
        } catch {
            return nil
        }
    }
}
