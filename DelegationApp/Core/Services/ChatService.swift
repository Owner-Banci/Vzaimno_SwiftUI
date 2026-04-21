import Foundation

protocol ChatService {
    func fetchThreads(token: String) async throws -> [ChatThreadPreview]
    func fetchRealtimeCapabilities(token: String) async throws -> ChatRealtimeCapabilities
    func fetchMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage]
    func sendMessage(token: String, threadID: String, text: String) async throws -> ChatMessage
    func fetchActiveDispute(token: String, threadID: String) async throws -> DisputeState?
    func openDispute(
        token: String,
        threadID: String,
        problemTitle: String,
        problemDescription: String,
        requestedCompensationRub: Int,
        desiredResolution: String
    ) async throws -> DisputeState
    func acceptCounterpartyDispute(token: String, threadID: String, disputeID: String) async throws -> DisputeState
    func respondCounterpartyDispute(
        token: String,
        threadID: String,
        disputeID: String,
        responseDescription: String,
        acceptableRefundPercent: Int,
        desiredResolution: String
    ) async throws -> DisputeState
    func selectDisputeOption(
        token: String,
        threadID: String,
        disputeID: String,
        optionID: String
    ) async throws -> DisputeState
    func ensureSupportThread(token: String) async throws -> String
    func fetchSupportMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage]
    func sendSupportMessage(token: String, threadID: String, text: String) async throws -> ChatMessage
    func fetchReportReasonOptions(token: String) async throws -> [ReportReasonOption]
    func submitReport(
        token: String,
        targetType: String,
        targetID: String,
        reasonCode: String,
        reasonText: String?
    ) async throws
}

final class NetworkChatService: ChatService {
    private let api: APIClient
    private let encoder = ISO8601DateFormatter()
    private var hasEnsuredSupportThread = false

    init(api: APIClient = APIClient()) {
        self.api = api
        self.encoder.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func fetchThreads(token: String) async throws -> [ChatThreadPreview] {
        if !hasEnsuredSupportThread {
            do {
                _ = try await ensureSupportThread(token: token)
                hasEnsuredSupportThread = true
            } catch {
                if error.isUnauthorizedResponse {
                    throw error
                }
            }
        }
        let response: [ChatThreadPreviewDTO] = try await api.request(.chats, token: token)
        return response.map(\.domain)
    }

    func fetchRealtimeCapabilities(token: String) async throws -> ChatRealtimeCapabilities {
        let response: ChatRealtimeCapabilitiesDTO = try await api.request(.chatsRealtimeCapabilities, token: token)
        return response.domain
    }

    func fetchMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        let beforeValue = before.map { encoder.string(from: $0) }
        let response: [ChatMessageDTO] = try await api.request(
            .chatMessages(threadID: threadID, limit: limit, before: beforeValue),
            token: token
        )
        return response.map(\.domain)
    }

    func sendMessage(token: String, threadID: String, text: String) async throws -> ChatMessage {
        let request = SendChatMessageRequestDTO(text: text)
        let response: ChatMessageDTO = try await api.request(.sendChatMessage(threadID: threadID), body: request, token: token)
        return response.domain
    }

    func fetchActiveDispute(token: String, threadID: String) async throws -> DisputeState? {
        do {
            let response: DisputeStateDTO? = try await api.request(.activeDispute(threadID: threadID), token: token)
            return response?.domain
        } catch let error as APIClient.APIError where error.statusCode == 404 {
            // Backward-compatible fallback for older backend contract.
            return nil
        }
    }

    func openDispute(
        token: String,
        threadID: String,
        problemTitle: String,
        problemDescription: String,
        requestedCompensationRub: Int,
        desiredResolution: String
    ) async throws -> DisputeState {
        let request = OpenDisputeRequestDTO(
            problem_title: problemTitle,
            problem_description: problemDescription,
            requested_compensation_rub: max(0, requestedCompensationRub),
            desired_resolution: desiredResolution
        )
        let response: DisputeStateDTO = try await api.request(.openDispute(threadID: threadID), body: request, token: token)
        return response.domain
    }

    func acceptCounterpartyDispute(token: String, threadID: String, disputeID: String) async throws -> DisputeState {
        let response: DisputeStateDTO = try await api.request(
            .acceptCounterpartyDispute(threadID: threadID, disputeID: disputeID),
            body: Optional<Int>.none,
            token: token
        )
        return response.domain
    }

    func respondCounterpartyDispute(
        token: String,
        threadID: String,
        disputeID: String,
        responseDescription: String,
        acceptableRefundPercent: Int,
        desiredResolution: String
    ) async throws -> DisputeState {
        let request = CounterpartyDisputeResponseRequestDTO(
            response_description: responseDescription,
            acceptable_refund_percent: max(0, min(100, acceptableRefundPercent)),
            desired_resolution: desiredResolution
        )
        let response: DisputeStateDTO = try await api.request(
            .respondCounterpartyDispute(threadID: threadID, disputeID: disputeID),
            body: request,
            token: token
        )
        return response.domain
    }

    func selectDisputeOption(
        token: String,
        threadID: String,
        disputeID: String,
        optionID: String
    ) async throws -> DisputeState {
        let request = SelectDisputeOptionRequestDTO(option_id: optionID)
        let response: DisputeStateDTO = try await api.request(
            .selectDisputeOption(threadID: threadID, disputeID: disputeID),
            body: request,
            token: token
        )
        return response.domain
    }

    func ensureSupportThread(token: String) async throws -> String {
        let response: SupportThreadDTO = try await api.request(.supportThread, token: token)
        return response.thread_id
    }

    func fetchSupportMessages(token: String, threadID: String, limit: Int, before: Date?) async throws -> [ChatMessage] {
        let beforeValue = before.map { encoder.string(from: $0) }
        let response: [ChatMessageDTO] = try await api.request(
            .supportMessages(threadID: threadID, limit: limit, before: beforeValue),
            token: token
        )
        return response.map(\.domain)
    }

    func sendSupportMessage(token: String, threadID: String, text: String) async throws -> ChatMessage {
        let request = SendChatMessageRequestDTO(text: text)
        let response: ChatMessageDTO = try await api.request(.sendSupportMessage(threadID: threadID), body: request, token: token)
        return response.domain
    }

    func fetchReportReasonOptions(token: String) async throws -> [ReportReasonOption] {
        let response: [ReportReasonOptionDTO] = try await api.request(.reportReasonCodes, token: token)
        return response.map(\.domain)
    }

    func submitReport(
        token: String,
        targetType: String,
        targetID: String,
        reasonCode: String,
        reasonText: String?
    ) async throws {
        let request = ReportSubmissionRequestDTO(
            target_type: targetType,
            target_id: targetID,
            reason_code: reasonCode,
            reason_text: normalizedReportComment(reasonText)
        )
        let _: ReportDTO = try await api.request(.submitReport, body: request, token: token)
    }
}

private func normalizedReportComment(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
