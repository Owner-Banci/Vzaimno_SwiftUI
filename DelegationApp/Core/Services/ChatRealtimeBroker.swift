import Foundation

struct ChatThreadActivity: Equatable {
    let threadID: String
    let text: String
    let createdAt: Date
    let senderID: String
    let incrementUnread: Bool
}

enum ChatRealtimeBroker {
    static let notificationName = Notification.Name("ChatRealtimeBroker.threadActivity")
    private static let activityKey = "activity"

    static func publish(_ activity: ChatThreadActivity) {
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: [activityKey: activity]
        )
    }

    static func activity(from notification: Notification) -> ChatThreadActivity? {
        notification.userInfo?[activityKey] as? ChatThreadActivity
    }
}
