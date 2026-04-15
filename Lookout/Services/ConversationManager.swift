import SwiftUI

@MainActor
final class ConversationManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isStreaming = false
    @Published var streamingContent = ""
    @Published var apiKey: String = ""
    @Published var statusText: String?

    private let claudeAPI = ClaudeAPIService()
    private let screenCapture = ScreenCaptureService()
    private let systemContext = SystemContextService()
    private let actionService = ActionService()

    /// Callback for showing screen overlay highlights — wired by AppDelegate.
    var onHighlight: ((NSPoint, CGFloat, String?) -> Void)? {
        didSet { actionService.onHighlight = onHighlight }
    }

    /// Full API conversation history (includes tool use messages not shown in chat).
    private var apiConversation: [[String: Any]] = []

    /// Timestamp of the last user message — used for inactivity-based screenshot.
    private var lastMessageTime: Date?

    /// Cached summary of older conversation turns.
    private var conversationSummary: String?

    // MARK: - Configuration

    /// How long before we auto-include screenshots again.
    private let inactivityThreshold: TimeInterval = 120

    /// Messages with images older than this (from the end) get images stripped.
    private let keepImagesInLast = 4

    /// When apiConversation exceeds this, trigger summarization of older messages.
    private let summarizeThreshold = 40

    /// Number of recent messages to keep intact after summarization.
    private let recentToKeep = 12

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasScreenPermission: Bool { ScreenCaptureService.hasPermission }

    init() {
        // Check UserDefaults first, then fall back to ANTHROPIC_API_KEY env var
        let saved = UserDefaults.standard.string(forKey: "lookout_api_key") ?? ""
        if !saved.isEmpty {
            self.apiKey = saved
        } else {
            self.apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        }
    }

    func saveAPIKey(_ key: String) {
        apiKey = key
        UserDefaults.standard.set(key, forKey: "lookout_api_key")
    }

    // MARK: - Screenshot Decision

    private var shouldAutoCapture: Bool {
        if messages.isEmpty { return true }
        guard let last = lastMessageTime else { return true }
        return Date().timeIntervalSince(last) > inactivityThreshold
    }

    // MARK: - Send Message

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        let autoCapture = shouldAutoCapture

        // Gather system context (always) + screenshots (only if auto-capturing)
        async let contextResult = systemContext.gatherContext()
        let screenshots: [Data]
        if autoCapture {
            screenshots = await screenCapture.captureAllDisplays()
            if screenshots.isEmpty && !ScreenCaptureService.hasPermission {
                messages.append(Message(
                    role: .assistant,
                    content: "I need Screen Recording permission to see your screen.\n\nOpen **System Settings \u{2192} Privacy & Security \u{2192} Screen Recording** and enable Lookout, then relaunch the app."
                ))
                return
            }
        } else {
            screenshots = []
        }

        let context = await contextResult
        lastMessageTime = Date()

        // Enrich user text with system context
        var contextLines = context.description
        if autoCapture && screenshots.count > 1 {
            contextLines += "\nDisplays captured: \(screenshots.count)"
        }
        if !autoCapture {
            contextLines += "\n(No screenshot auto-attached \u{2014} use capture_screen tool if needed)"
        }
        let enrichedContent = "\(trimmed)\n\n[System Context]\n\(contextLines)"

        // Add user message to chat UI
        messages.append(Message(role: .user, content: trimmed, screenshots: screenshots))

        // Build API message with optional screenshots
        var contentBlocks: [[String: Any]] = []
        for (i, screenshot) in screenshots.enumerated() {
            if screenshots.count > 1 {
                contentBlocks.append(["type": "text", "text": "[Display \(i + 1)]"] as [String: Any])
            }
            contentBlocks.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": screenshot.base64EncodedString()
                ] as [String: Any]
            ] as [String: Any])
        }
        contentBlocks.append(["type": "text", "text": enrichedContent] as [String: Any])
        apiConversation.append(["role": "user", "content": contentBlocks])

        isStreaming = true
        streamingContent = ""
        statusText = autoCapture ? "Looking at your screen..." : "Thinking..."

        await runResponseLoop()

        isStreaming = false
        statusText = nil

        // Compact conversation in the background if it's getting long
        if apiConversation.count > summarizeThreshold {
            await compactConversation()
        }
    }

    // MARK: - Response Loop (handles tool calls)

    private func runResponseLoop() async {
        var toolCallDepth = 0
        let maxToolCalls = 10

        while toolCallDepth < maxToolCalls {
            do {
                // Send trimmed messages (old images stripped)
                let trimmedMessages = prepareMessagesForAPI()
                let stream = claudeAPI.streamResponse(
                    messages: trimmedMessages,
                    apiKey: apiKey
                )

                var textSoFar = ""
                var pendingToolCalls: [(id: String, name: String, input: [String: Any])] = []

                for try await event in stream {
                    switch event {
                    case .text(let delta):
                        textSoFar += delta
                        streamingContent = textSoFar
                    case .toolUse(let id, let name, let input):
                        pendingToolCalls.append((id: id, name: name, input: input))
                    case .done:
                        break
                    }
                }

                if !pendingToolCalls.isEmpty {
                    if !textSoFar.isEmpty {
                        messages.append(Message(role: .assistant, content: textSoFar))
                        streamingContent = ""
                    }

                    var assistantContent: [[String: Any]] = []
                    if !textSoFar.isEmpty {
                        assistantContent.append(["type": "text", "text": textSoFar])
                    }
                    for call in pendingToolCalls {
                        assistantContent.append([
                            "type": "tool_use",
                            "id": call.id,
                            "name": call.name,
                            "input": call.input
                        ] as [String: Any])
                    }
                    apiConversation.append(["role": "assistant", "content": assistantContent])

                    var toolResults: [[String: Any]] = []
                    for call in pendingToolCalls {
                        statusText = call.name == "capture_screen"
                            ? "Capturing screen..."
                            : "Running \(call.name)..."

                        let result = await actionService.execute(toolName: call.name, input: call.input)

                        if result.images.isEmpty {
                            toolResults.append([
                                "type": "tool_result",
                                "tool_use_id": call.id,
                                "content": result.output
                            ] as [String: Any])
                        } else {
                            var content: [[String: Any]] = []
                            for (i, imageData) in result.images.enumerated() {
                                if result.images.count > 1 {
                                    content.append(["type": "text", "text": "[Display \(i + 1)]"] as [String: Any])
                                }
                                content.append([
                                    "type": "image",
                                    "source": [
                                        "type": "base64",
                                        "media_type": "image/jpeg",
                                        "data": imageData.base64EncodedString()
                                    ] as [String: Any]
                                ] as [String: Any])
                            }
                            content.append(["type": "text", "text": result.output] as [String: Any])
                            toolResults.append([
                                "type": "tool_result",
                                "tool_use_id": call.id,
                                "content": content
                            ] as [String: Any])
                        }
                    }

                    apiConversation.append(["role": "user", "content": toolResults])
                    statusText = "Thinking..."
                    streamingContent = ""
                    toolCallDepth += 1
                    continue
                }

                // Final text response
                if !textSoFar.isEmpty {
                    messages.append(Message(role: .assistant, content: textSoFar))
                    apiConversation.append(ClaudeAPIService.assistantMessage(text: textSoFar))
                }
                streamingContent = ""
                return

            } catch {
                let errorText = (error as? ClaudeAPIService.APIError)?.message ?? error.localizedDescription
                messages.append(Message(role: .assistant, content: "Something went wrong: \(errorText)"))
                streamingContent = ""
                return
            }
        }

        messages.append(Message(role: .assistant, content: "I've done several things but need to stop here. Let me know if you need anything else!"))
    }

    // MARK: - Conversation Management

    /// Build the message array for the API: strip old images, prepend summary if available.
    private func prepareMessagesForAPI() -> [[String: Any]] {
        var prepared: [[String: Any]] = []

        // If we have a summary from compaction, lead with it
        if let summary = conversationSummary {
            prepared.append([
                "role": "user",
                "content": "[Earlier conversation summary]\n\(summary)\n\n[The conversation continues below.]"
            ])
            prepared.append([
                "role": "assistant",
                "content": "Got it \u{2014} I have the context from our earlier conversation."
            ])
        }

        // Add all current messages, stripping images from old ones
        let imageKeepStart = max(0, apiConversation.count - keepImagesInLast)
        for (i, msg) in apiConversation.enumerated() {
            if i < imageKeepStart {
                prepared.append(stripImages(from: msg))
            } else {
                prepared.append(msg)
            }
        }

        return prepared
    }

    /// Replace image blocks with "[screenshot]" placeholder text.
    private func stripImages(from message: [String: Any]) -> [String: Any] {
        var msg = message
        guard let content = msg["content"] as? [[String: Any]] else { return msg }

        let filtered: [[String: Any]] = content.compactMap { block in
            guard let type = block["type"] as? String else { return block }

            if type == "image" {
                return ["type": "text", "text": "[screenshot]"] as [String: Any]
            }

            // Also strip images inside tool_result blocks
            if type == "tool_result", let inner = block["content"] as? [[String: Any]] {
                let stripped = inner.compactMap { innerBlock -> [String: Any]? in
                    if (innerBlock["type"] as? String) == "image" {
                        return ["type": "text", "text": "[screenshot]"] as [String: Any]
                    }
                    return innerBlock
                }
                var newBlock = block
                newBlock["content"] = stripped
                return newBlock
            }

            return block
        }

        msg["content"] = filtered
        return msg
    }

    /// Summarize older conversation turns and trim the apiConversation array.
    private func compactConversation() async {
        let cutoff = apiConversation.count - recentToKeep
        guard cutoff > 2 else { return }

        statusText = "Compacting history..."

        // Extract text from the older messages for summarization
        let olderMessages = Array(apiConversation[0..<cutoff])
        var textParts: [String] = []
        for msg in olderMessages {
            let role = (msg["role"] as? String) ?? "?"
            if let content = msg["content"] as? String {
                textParts.append("\(role): \(content)")
            } else if let blocks = msg["content"] as? [[String: Any]] {
                for block in blocks {
                    if let text = block["text"] as? String, (block["type"] as? String) == "text" {
                        // Skip system context blocks in summary input
                        if !text.hasPrefix("[System Context]") && !text.hasPrefix("[screenshot]") {
                            textParts.append("\(role): \(text)")
                        }
                    }
                    if let toolName = block["name"] as? String {
                        let input = block["input"] as? [String: Any] ?? [:]
                        textParts.append("tool_use: \(toolName)(\(input))")
                    }
                }
            }
        }

        let conversationText = textParts.joined(separator: "\n")
        guard !conversationText.isEmpty else { return }

        if let summary = await claudeAPI.summarize(conversationText: conversationText, apiKey: apiKey) {
            conversationSummary = summary
            // Trim old messages, keeping only the recent ones
            apiConversation = Array(apiConversation[cutoff...])
        }

        statusText = nil
    }

    func clearConversation() {
        messages = []
        apiConversation = []
        streamingContent = ""
        statusText = nil
        lastMessageTime = nil
        conversationSummary = nil
    }
}
