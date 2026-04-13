import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var conversation: ConversationManager
    @State private var apiKeyInput = ""
    @State private var showKey = false
    @State private var saved = false

    var body: some View {
        Form {
            Section("Claude API Key") {
                HStack {
                    if showKey {
                        TextField("sk-ant-...", text: $apiKeyInput)
                    } else {
                        SecureField("sk-ant-...", text: $apiKeyInput)
                    }
                    Button(showKey ? "Hide" : "Show") {
                        showKey.toggle()
                    }
                }

                HStack {
                    Button("Save") {
                        conversation.saveAPIKey(apiKeyInput)
                        saved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                    }
                    .disabled(apiKeyInput.isEmpty)

                    if saved {
                        Text("Saved!")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Text("Get your API key at console.anthropic.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Screen Recording") {
                HStack {
                    Image(systemName: conversation.hasScreenPermission
                          ? "checkmark.circle.fill"
                          : "xmark.circle.fill")
                    .foregroundStyle(conversation.hasScreenPermission ? .green : .red)

                    Text(conversation.hasScreenPermission
                         ? "Permission granted"
                         : "Permission required")

                    Spacer()

                    if !conversation.hasScreenPermission {
                        Button("Open Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                LabeledContent("Model", value: "Claude Sonnet 4")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
        .onAppear { apiKeyInput = conversation.apiKey }
    }
}
