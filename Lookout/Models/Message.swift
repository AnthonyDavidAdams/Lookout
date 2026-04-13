import Foundation

struct Message: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    /// One JPEG per display captured with this message.
    let screenshots: [Data]

    init(role: MessageRole, content: String, screenshots: [Data] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.screenshots = screenshots
    }

    enum MessageRole: String {
        case user
        case assistant
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content
    }
}
