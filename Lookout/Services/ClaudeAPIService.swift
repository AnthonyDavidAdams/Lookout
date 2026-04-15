import Foundation

final class ClaudeAPIService {

    static let baseSystemPrompt = """
        You are Lookout, a friendly AI screen assistant. You can see the user's \
        screen and help them navigate their computer.

        Screenshots are automatically included at the start of a conversation or \
        after the user has been away. For follow-up messages, use the capture_screen \
        tool when you need to see what's currently on screen — for example, after the \
        user says they did something, or when you need to verify a change. Don't \
        capture unless you actually need to see the screen.

        Guidelines:
        - Reference specific things you see: app names, button labels, menu items, \
          window titles, visible text
        - Be specific about locations: "the blue Save button in the top-right corner" \
          not just "the button"
        - Give 1-2 clear next steps at a time, not long tutorials
        - Be conversational, encouraging, and patient
        - If you can't see something clearly in the screenshot, say so
        - Ignore the Lookout chat window if visible in screenshots
        - Each message includes a [System Context] block with running apps and \
          visible window titles

        You have tools to take actions on the user's computer:
        - capture_screen: take a fresh screenshot of all displays
        - highlight_element: point an arrow at a specific button/text on screen \
          (uses OCR to find it, draws a pulsing highlight). Use this whenever you \
          tell the user to click something — show them exactly where it is.
        - list_applications: see what's installed
        - search_files: find files and folders by name or content
        - open_item: open an app, file, or folder
        - save_note: save an observation about the user for future conversations
        - read_notes: recall what you know about this user from past sessions

        At the start of a new conversation, use read_notes to recall what you know \
        about this user. As you help them, use save_note to remember useful things: \
        what they struggle with, what apps they use, their skill level, projects \
        they're working on, preferences. Keep notes concise and useful. Don't save \
        every interaction — just things that would help you be a better assistant \
        next time.

        Be helpful and proactive. If the user needs something opened or found, just \
        do it. You're like a knowledgeable friend helping them with their computer.
        """

    /// Build the full system prompt, including any custom user context from ~/.lookout/context.md
    static var systemPrompt: String {
        let custom = CustomContextService().loadContext()
        if let custom = custom {
            return baseSystemPrompt + "\n\n[User Context]\n" + custom
        }
        return baseSystemPrompt
    }

    static let tools: [[String: Any]] = [
        [
            "name": "capture_screen",
            "description": "Capture a fresh screenshot of all connected displays. Use this when you need to see what's currently on screen — e.g., after the user says they've completed a step, or you need to verify the current state. No need to call this if a recent screenshot was already provided.",
            "input_schema": [
                "type": "object",
                "properties": [:] as [String: Any],
                "required": [] as [String]
            ] as [String: Any]
        ],
        [
            "name": "list_applications",
            "description": "List all applications installed on this Mac.",
            "input_schema": [
                "type": "object",
                "properties": [:] as [String: Any],
                "required": [] as [String]
            ] as [String: Any]
        ],
        [
            "name": "search_files",
            "description": "Search for files and folders by name or content using Spotlight. Returns up to 20 results.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "Search query (file name, content, or kind e.g. 'kind:pdf budget')"
                    ] as [String: Any],
                    "directory": [
                        "type": "string",
                        "description": "Optional directory to search in. Defaults to home folder."
                    ] as [String: Any]
                ] as [String: Any],
                "required": ["query"]
            ] as [String: Any]
        ],
        [
            "name": "open_item",
            "description": "Open a file, folder, or application. For apps, just use the name (e.g. 'Safari'). For files/folders, use the full path.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "path": [
                        "type": "string",
                        "description": "App name (e.g. 'Safari'), bundle ID, or full file/folder path"
                    ] as [String: Any]
                ] as [String: Any],
                "required": ["path"]
            ] as [String: Any]
        ],
        [
            "name": "save_note",
            "description": "Save a note about the user — what they're working on, things they struggle with, preferences you've observed, or anything useful for future conversations. Notes persist across sessions in ~/.lookout/notes.md.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "note": [
                        "type": "string",
                        "description": "The observation or note to save about the user"
                    ] as [String: Any]
                ] as [String: Any],
                "required": ["note"]
            ] as [String: Any]
        ],
        [
            "name": "highlight_element",
            "description": "Highlight a specific UI element on the user's screen. Uses OCR to find the text and draws a pulsing arrow pointing directly at it. Also returns a cropped screenshot of the area. Use this when pointing the user to a specific button, menu item, or text on screen.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "text_to_find": [
                        "type": "string",
                        "description": "The exact text to find on screen (button label, menu item, etc.)"
                    ] as [String: Any],
                    "label": [
                        "type": "string",
                        "description": "Optional label to display next to the highlight arrow (e.g. 'Click here')"
                    ] as [String: Any]
                ] as [String: Any],
                "required": ["text_to_find"]
            ] as [String: Any]
        ],
        [
            "name": "read_notes",
            "description": "Read all saved notes about this user from previous conversations. Check this at the start of a conversation to recall what you know about them.",
            "input_schema": [
                "type": "object",
                "properties": [:] as [String: Any],
                "required": [] as [String]
            ] as [String: Any]
        ]
    ]

    struct APIError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Parsed content from a streamed response.
    enum StreamEvent {
        case text(String)
        case toolUse(id: String, name: String, input: [String: Any])
        case done
    }

    /// Stream a response from Claude, yielding text deltas and tool calls.
    func streamResponse(
        messages: [[String: Any]],
        apiKey: String,
        model: String = "claude-sonnet-4-20250514"
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                        throw APIError(message: "Invalid API URL")
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    request.timeoutInterval = 120

                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 4096,
                        "stream": true,
                        "system": Self.systemPrompt,
                        "tools": Self.tools,
                        "messages": messages
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw APIError(message: "Invalid response from server")
                    }

                    if httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        throw APIError(message: "API error (\(httpResponse.statusCode)): \(errorBody)")
                    }

                    var currentToolID: String?
                    var currentToolName: String?
                    var currentToolJSON = ""

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6))
                        guard jsonStr != "[DONE]" else { break }

                        guard let data = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String
                        else { continue }

                        switch type {
                        case "content_block_start":
                            if let block = json["content_block"] as? [String: Any],
                               let blockType = block["type"] as? String,
                               blockType == "tool_use" {
                                currentToolID = block["id"] as? String
                                currentToolName = block["name"] as? String
                                currentToolJSON = ""
                            }

                        case "content_block_delta":
                            if let delta = json["delta"] as? [String: Any],
                               let deltaType = delta["type"] as? String {
                                if deltaType == "text_delta",
                                   let text = delta["text"] as? String {
                                    continuation.yield(.text(text))
                                } else if deltaType == "input_json_delta",
                                          let partial = delta["partial_json"] as? String {
                                    currentToolJSON += partial
                                }
                            }

                        case "content_block_stop":
                            if let toolID = currentToolID,
                               let toolName = currentToolName {
                                let input: [String: Any]
                                if let jsonData = currentToolJSON.data(using: .utf8),
                                   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                    input = parsed
                                } else {
                                    input = [:]
                                }
                                continuation.yield(.toolUse(id: toolID, name: toolName, input: input))
                                currentToolID = nil
                                currentToolName = nil
                                currentToolJSON = ""
                            }

                        case "message_stop":
                            continuation.yield(.done)

                        case "error":
                            if let error = json["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                throw APIError(message: message)
                            }

                        default:
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Summarization

    /// Quick, non-streaming call to Haiku to summarize older conversation history.
    func summarize(conversationText: String, apiKey: String) async -> String? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "system": "Summarize this conversation between a user and Lookout (an AI screen assistant). Preserve key details: what the user asked for, what was done, what tools were used, decisions made, and current state. Be concise but don't lose important context. Write in third person past tense.",
            "messages": [
                ["role": "user", "content": conversationText]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String {
                return text
            }
        } catch {}
        return nil
    }

    // MARK: - Message Building Helpers

    static func assistantMessage(text: String) -> [String: Any] {
        ["role": "assistant", "content": text]
    }
}
