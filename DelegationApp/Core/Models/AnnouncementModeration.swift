//
//  AnnouncementModeration.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 27.02.2026.
//

import Foundation
import SwiftUI

enum ModerationSeverity: Int, Comparable {
    case none = 0
    case warning = 1   // can_appeal = true (жёлтый)
    case danger = 2    // can_appeal = false (красный)

    static func < (lhs: ModerationSeverity, rhs: ModerationSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .warning: return .yellow
        case .danger: return .red
        }
    }
}

struct ModerationReason: Identifiable {
    let id = UUID()
    let field: String
    let code: String
    let details: String
    let canAppeal: Bool

    var severity: ModerationSeverity { canAppeal ? .warning : .danger }

    var isTechnicalIssue: Bool {
        let normalizedCode = code.uppercased()
        let normalizedDetails = details.lowercased()

        if normalizedCode == "TEXT_SYSTEM_UNAVAILABLE" || normalizedCode == "MEDIA_SYSTEM_UNAVAILABLE" {
            return true
        }

        if normalizedCode == "TEXT_UNKNOWN",
           (normalizedDetails.contains("ollama error")
            || normalizedDetails.contains("timed out")
            || normalizedDetails.contains("connection refused")
            || normalizedDetails.contains("non-json")
            || normalizedDetails.contains("не-json")) {
            return true
        }

        return false
    }
}

struct ModerationDecision {
    let status: String?
    let message: String?
}

struct ModerationPayload {
    let decision: ModerationDecision?
    let reasons: [ModerationReason]
    let suggestions: [String]
}

// MARK: - JSONValue helpers (локально, чтобы не ломать существующий код)
extension JSONValue {
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }
    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
}

extension AnnouncementDTO {
    private var visibleModerationReasons: [ModerationReason] {
        (moderationPayload?.reasons ?? []).filter { !$0.isTechnicalIssue }
    }

    private var hasOnlyTechnicalModerationIssues: Bool {
        guard let reasons = moderationPayload?.reasons, !reasons.isEmpty else { return false }
        return reasons.allSatisfy(\.isTechnicalIssue)
    }

    var normalizedStatus: String {
        switch status.lowercased() {
        case "draft", "pending", "review", "pending/review", "in_review":
            return "pending_review"
        case "declined":
            return "rejected"
        case "open":
            return "active"
        default:
            return status.lowercased()
        }
    }

    var isActiveStatus: Bool {
        let status = normalizedStatus
        return status == "active" || status == "assigned" || status == "in_progress"
    }

    var isActionsStatus: Bool {
        let status = normalizedStatus
        return status == "pending_review" || status == "needs_fix"
    }

    var isArchivedStatus: Bool {
        let status = normalizedStatus
        return status == "archived" || status == "rejected" || status == "completed" || status == "deleted"
    }

    var needsStatusPolling: Bool {
        normalizedStatus == "pending_review"
    }

    var moderationPayload: ModerationPayload? {
        guard let modObj = data["moderation"]?.objectValue else { return nil }

        // decision
        var decision: ModerationDecision?
        if let d = modObj["decision"]?.objectValue {
            decision = ModerationDecision(
                status: d["status"]?.stringValue,
                message: d["message"]?.stringValue
            )
        }

        // reasons
        var reasons: [ModerationReason] = []
        if let arr = modObj["reasons"]?.arrayValue {
            for item in arr {
                guard let o = item.objectValue else { continue }
                let field = o["field"]?.stringValue ?? ""
                let code = o["code"]?.stringValue ?? ""
                let details = o["details"]?.stringValue ?? ""
                let canAppeal = o["can_appeal"]?.boolValue ?? true
                if !field.isEmpty {
                    reasons.append(.init(field: field, code: code, details: details, canAppeal: canAppeal))
                }
            }
        }

        // suggestions
        var suggestions: [String] = []
        if let arr = modObj["suggestions"]?.arrayValue {
            suggestions = arr.compactMap { $0.stringValue }.filter { !$0.isEmpty }
        }

        return ModerationPayload(decision: decision, reasons: reasons, suggestions: suggestions)
    }

    var decisionMessage: String? {
        if normalizedStatus == "active", hasOnlyTechnicalModerationIssues {
            return nil
        }

        if hasOnlyTechnicalModerationIssues {
            return "Автоматическая проверка временно недоступна. Объявление ждёт дополнительной проверки."
        }

        guard let message = moderationPayload?.decision?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
              !message.isEmpty else {
            return nil
        }

        if !hasAttachedMedia,
           normalizedStatus == "pending_review",
           message.localizedCaseInsensitiveContains("проверим фото") {
            return "На проверке: объявление отправлено на модерацию."
        }

        return message
    }

    var maxReasonSeverity: ModerationSeverity {
        visibleModerationReasons.map(\.severity).max() ?? .none
    }

    func severity(for field: String) -> ModerationSeverity {
        return visibleModerationReasons
            .filter { $0.field == field }
            .map { $0.severity }
            .max() ?? .none
    }

    var hasModerationIssues: Bool {
        !visibleModerationReasons.isEmpty
    }
}
