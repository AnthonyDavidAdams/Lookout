import SwiftUI

struct MessageView: View {
    let message: Message

    private static let markdownOptions = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
    )

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tint)
                    .padding(.top, 4)
            } else {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Screenshot thumbnails for user messages
                if !message.screenshots.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(message.screenshots.enumerated()), id: \.offset) { _, data in
                            if let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: message.screenshots.count > 1 ? 50 : 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .opacity(0.85)
                            }
                        }
                    }
                }

                // Message text with markdown + preserved newlines
                messageBubble
            }

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var messageBubble: some View {
        let text: Text = {
            if let attributed = try? AttributedString(
                markdown: message.content,
                options: Self.markdownOptions
            ) {
                return Text(attributed)
            } else {
                return Text(message.content)
            }
        }()

        text
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(message.role == .user
                          ? Color.accentColor
                          : Color(.controlBackgroundColor))
            )
            .foregroundStyle(message.role == .user ? .white : .primary)
    }
}
