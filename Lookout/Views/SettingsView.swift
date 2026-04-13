import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var conversation: ConversationManager
    @State private var apiKeyInput = ""
    @State private var showKey = false
    @State private var saved = false
    @State private var contextText = ""
    @State private var contextSaved = false

    private let contextService = CustomContextService()

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            contextTab
                .tabItem { Label("Context", systemImage: "person.text.rectangle") }
        }
        .frame(width: 480, height: 380)
        .onAppear {
            apiKeyInput = conversation.apiKey
            contextText = loadRawContext()
        }
    }

    // MARK: - General

    private var generalTab: some View {
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
    }

    // MARK: - Context

    private var contextTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Context")
                .font(.headline)

            Text("Tell Lookout about yourself so it can give better answers. This is included in every conversation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $contextText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.textBackgroundColor))
                )
                .frame(minHeight: 160)

            HStack {
                Button("Save") {
                    saveContext()
                    contextSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { contextSaved = false }
                }

                if contextSaved {
                    Text("Saved!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                Button("Open in Editor") {
                    let path = NSHomeDirectory() + "/.lookout/context.md"
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            Text("Examples: \"I'm not very technical\", \"I use Photoshop for work\", \"My name is Mom\"")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func loadRawContext() -> String {
        let path = NSHomeDirectory() + "/.lookout/context.md"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return ""
        }
        // Strip the template header, keep user content
        let lines = content.components(separatedBy: "\n")
        if let markerIndex = lines.firstIndex(where: { $0.contains("Delete the examples") }) {
            let userContent = lines[(markerIndex + 1)...].joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return userContent
        }
        // If no marker, return everything that isn't a heading
        return lines
            .filter { !$0.hasPrefix("# ") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveContext() {
        let path = NSHomeDirectory() + "/.lookout/context.md"
        let dir = NSHomeDirectory() + "/.lookout"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let content = "# Lookout Custom Context\n\n\(contextText.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
