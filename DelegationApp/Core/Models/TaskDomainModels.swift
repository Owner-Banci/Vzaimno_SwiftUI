import Foundation

enum TaskLifecycleStatus: String, CaseIterable, Equatable {
    case draft
    case pendingReview = "pending_review"
    case needsFix = "needs_fix"
    case open
    case assigned
    case inProgress = "in_progress"
    case completed
    case cancelled
    case archived
    case rejected
    case deleted

    init(statusValue: String?, legacyAnnouncementStatus: String?, isDeleted: Bool) {
        if isDeleted {
            self = .deleted
            return
        }

        let raw = (statusValue ?? legacyAnnouncementStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch raw {
        case "draft":
            self = .draft
        case "pending_review", "pending", "review", "in_review":
            self = .pendingReview
        case "needs_fix":
            self = .needsFix
        case "open", "active", "published":
            self = .open
        case "assigned":
            self = .assigned
        case "in_progress", "executing":
            self = .inProgress
        case "completed", "done":
            self = .completed
        case "cancelled", "canceled":
            self = .cancelled
        case "archived":
            self = .archived
        case "rejected":
            self = .rejected
        case "deleted":
            self = .deleted
        default:
            self = .open
        }
    }

    var keepsTaskPublic: Bool {
        self == .open
    }
}

enum TaskExecutionStatus: String, CaseIterable, Equatable {
    case open
    case awaitingAcceptance = "awaiting_acceptance"
    case accepted
    case enRoute = "en_route"
    case onSite = "on_site"
    case inProgress = "in_progress"
    case handoff
    case completed
    case cancelled
    case disputed

    init(statusValue: String?) {
        let raw = (statusValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch raw {
        case "awaiting_acceptance":
            self = .awaitingAcceptance
        case "accepted", "assigned":
            self = .accepted
        case "en_route", "heading", "route":
            self = .enRoute
        case "on_site", "onsite", "arrived":
            self = .onSite
        case "in_progress", "doing", "progress":
            self = .inProgress
        case "handoff", "finishing", "delivering":
            self = .handoff
        case "completed", "done", "finish":
            self = .completed
        case "cancelled", "canceled":
            self = .cancelled
        case "disputed":
            self = .disputed
        default:
            self = .open
        }
    }

    var blocksNewOffers: Bool {
        switch self {
        case .accepted, .enRoute, .onSite, .inProgress, .handoff, .completed, .cancelled, .disputed:
            return true
        case .open, .awaitingAcceptance:
            return false
        }
    }

    var makesCustomerRouteVisible: Bool {
        switch self {
        case .accepted, .enRoute, .onSite, .inProgress, .handoff:
            return true
        case .open, .awaitingAcceptance, .completed, .cancelled, .disputed:
            return false
        }
    }
}

struct TaskBudgetProjection: Equatable {
    let min: Int?
    let max: Int?
    let quickOfferPrice: Int?
}

struct TaskVisibilityProjection: Equatable {
    let isVisibleOnMap: Bool
    let isOpenForOffers: Bool
    let customerCanSeeRoute: Bool
    let chatShouldRemainTaskBound: Bool
}

struct TaskStateProjection: Equatable {
    let schemaVersion: Int
    let lifecycleStatus: TaskLifecycleStatus
    let executionStatus: TaskExecutionStatus
    let acceptedConfirmed: Bool
    let budget: TaskBudgetProjection
    let visibility: TaskVisibilityProjection
    let isDeleted: Bool
}

extension AnnouncementDTO {
    var taskState: TaskStateProjection {
        let isDeleted = taskDateString(paths: [["task", "lifecycle", "deleted_at"]]) != nil
        let lifecycle = TaskLifecycleStatus(
            statusValue: taskStringValue(paths: [["task", "lifecycle", "status"]]),
            legacyAnnouncementStatus: status,
            isDeleted: isDeleted
        )
        let execution = TaskExecutionStatus(
            statusValue: taskStringValue(
                paths: [
                    ["task", "execution", "status"],
                    ["task", "assignment", "execution_status"],
                ],
                legacyKeys: ["execution_status"]
            )
        )
        let acceptedConfirmed = taskBoolValue(
            paths: [
                ["task", "execution", "accepted_confirmed"],
                ["task", "assignment", "accepted_confirmed"],
                ["execution", "accepted_confirmed"],
            ],
            legacyKeys: ["execution_status_confirmed"]
        ) ?? false

        let budgetMin = taskIntValue(
            paths: [["task", "budget", "min"]],
            legacyKeys: ["budget_min"]
        ) ?? budgetMinValue
        let budgetMax = taskIntValue(
            paths: [["task", "budget", "max"]],
            legacyKeys: ["budget_max", "budget"]
        ) ?? budgetMaxValue ?? budgetValue
        let quickOfferPrice = taskIntValue(
            paths: [["task", "offer_policy", "quick_offer_price"]],
            legacyKeys: ["quick_offer_price"]
        ) ?? budgetMin ?? budgetMax

        let isVisibleOnMap = lifecycle.keepsTaskPublic && !isDeleted && !execution.blocksNewOffers
        let isOpenForOffers = lifecycle.keepsTaskPublic && !isDeleted && !execution.blocksNewOffers
        let customerCanSeeRoute = !isDeleted && execution.makesCustomerRouteVisible

        return TaskStateProjection(
            schemaVersion: taskIntValue(paths: [["task", "schema_version"]]) ?? 1,
            lifecycleStatus: lifecycle,
            executionStatus: execution,
            acceptedConfirmed: acceptedConfirmed,
            budget: TaskBudgetProjection(
                min: budgetMin,
                max: budgetMax,
                quickOfferPrice: quickOfferPrice
            ),
            visibility: TaskVisibilityProjection(
                isVisibleOnMap: isVisibleOnMap,
                isOpenForOffers: isOpenForOffers,
                customerCanSeeRoute: customerCanSeeRoute,
                chatShouldRemainTaskBound: !isDeleted
            ),
            isDeleted: isDeleted
        )
    }

    var quickOfferPrice: Int? {
        taskState.budget.quickOfferPrice
    }

    var canAppearOnMap: Bool {
        taskState.visibility.isVisibleOnMap
    }

    var canAcceptOffers: Bool {
        taskState.visibility.isOpenForOffers
    }

    var customerCanSeeExecutionRoute: Bool {
        taskState.visibility.customerCanSeeRoute
    }

    func taskValue(at path: [String]) -> JSONValue? {
        guard !path.isEmpty else { return nil }

        var current: JSONValue = .object(data)
        for component in path {
            guard case .object(let object) = current, let next = object[component] else {
                return nil
            }
            current = next
        }

        return current
    }

    func taskStringValue(paths: [[String]], legacyKeys: [String] = []) -> String? {
        for path in paths {
            if let value = taskValue(at: path)?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }

        for key in legacyKeys {
            if let value = data[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }

        return nil
    }

    func taskBoolValue(paths: [[String]], legacyKeys: [String] = []) -> Bool? {
        for path in paths {
            if let value = taskValue(at: path)?.boolValue {
                return value
            }
        }

        for key in legacyKeys {
            if let value = data[key]?.boolValue {
                return value
            }
        }

        return nil
    }

    func taskIntValue(paths: [[String]], legacyKeys: [String] = []) -> Int? {
        for path in paths {
            if let value = taskValue(at: path) {
                return TaskProjectionParser.int(from: value)
            }
        }

        for key in legacyKeys {
            if let value = data[key] {
                return TaskProjectionParser.int(from: value)
            }
        }

        return nil
    }

    func taskDateString(paths: [[String]]) -> String? {
        for path in paths {
            if let value = taskValue(at: path)?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }
}

private enum TaskProjectionParser {
    static func int(from value: JSONValue) -> Int? {
        switch value {
        case .int(let intValue):
            return intValue
        case .double(let doubleValue):
            return Int(doubleValue.rounded())
        case .string(let stringValue):
            let normalized = stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            guard let parsed = Double(normalized) else { return nil }
            return Int(parsed.rounded())
        default:
            return nil
        }
    }
}
