import SwiftUI

struct ChatView: View {
    @EnvironmentObject var conversation: ConversationManager
    @State private var inputText = ""
    @State private var apiKeyInput = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eye.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Lookout")
                    .font(.headline)
                Spacer()

                if !conversation.messages.isEmpty {
                    Button {
                        conversation.clearConversation()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("New Conversation")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            Divider()

            if !conversation.hasAPIKey {
                apiKeySetupView
            } else {
                messagesArea

                Divider()

                inputBar
            }
        }
        .frame(minWidth: 360, minHeight: 400)
        .background(.regularMaterial)
    }

    // MARK: - API Key Setup

    private var apiKeySetupView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tint)

            Text("Enter your Claude API Key")
                .font(.title3)
                .fontWeight(.medium)

            Text("Get one at console.anthropic.com")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("sk-ant-...", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .onSubmit { saveKey() }

            Button("Get Started") { saveKey() }
                .buttonStyle(.borderedProminent)
                .disabled(apiKeyInput.isEmpty)

            Spacer()
        }
        .padding()
    }

    private func saveKey() {
        guard !apiKeyInput.isEmpty else { return }
        conversation.saveAPIKey(apiKeyInput)
    }

    // MARK: - Messages

    private var messagesArea: some View {
        Group {
            if conversation.messages.isEmpty && !conversation.isStreaming {
                welcomeView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(conversation.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }

                            // Streaming response
                            if conversation.isStreaming && !conversation.streamingContent.isEmpty {
                                MessageView(message: Message(
                                    role: .assistant,
                                    content: conversation.streamingContent
                                ))
                                .id("streaming")
                            }

                            // Loading / status indicator
                            if conversation.isStreaming && conversation.streamingContent.isEmpty {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(conversation.statusText ?? "Thinking...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .id("loading")
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: conversation.messages.count) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if let lastID = conversation.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            } else {
                                proxy.scrollTo("loading", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: conversation.streamingContent) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "eye.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("What can I help you with?")
                .font(.title3)
                .fontWeight(.medium)
            Text("I can see your screen and help you\nnavigate your computer.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about your screen...", text: $inputText)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }
                .disabled(conversation.isStreaming)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? .secondary
                            : Color.accentColor
                    )
            }
            .buttonStyle(.borderless)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || conversation.isStreaming)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { isInputFocused = true }
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        Task { await conversation.send(text) }
    }
}
