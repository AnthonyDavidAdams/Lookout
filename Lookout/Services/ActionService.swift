import AppKit
import ScreenCaptureKit

/// Executes actions on the user's behalf (open files, search, list apps, capture screen).
final class ActionService {

    struct ActionResult {
        let success: Bool
        let output: String
        let images: [Data]  // JPEG data (for capture_screen)

        init(success: Bool, output: String, images: [Data] = []) {
            self.success = success
            self.output = output
            self.images = images
        }
    }

    private let screenCapture = ScreenCaptureService()

    // MARK: - Capture Screen

    func captureScreen() async -> ActionResult {
        let screenshots = await screenCapture.captureAllDisplays()
        if screenshots.isEmpty {
            return ActionResult(success: false, output: "Could not capture screen. Screen Recording permission may not be granted.")
        }
        let label = screenshots.count == 1 ? "Captured 1 display" : "Captured \(screenshots.count) displays"
        return ActionResult(success: true, output: label, images: screenshots)
    }

    // MARK: - List Installed Applications

    func listApplications() -> ActionResult {
        var apps: [String] = []

        let searchPaths = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        let fm = FileManager.default
        for dir in searchPaths {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                apps.append(item.replacingOccurrences(of: ".app", with: ""))
            }
        }

        apps.sort()
        return ActionResult(success: true, output: apps.joined(separator: "\n"))
    }

    // MARK: - Search Files

    func searchFiles(query: String, directory: String?) -> ActionResult {
        let searchDir = directory ?? NSHomeDirectory()
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", searchDir, query]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .prefix(20)
            if lines.isEmpty {
                return ActionResult(success: true, output: "No results found for \"\(query)\"")
            }
            return ActionResult(success: true, output: lines.joined(separator: "\n"))
        } catch {
            return ActionResult(success: false, output: "Search failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Open File / Folder / App

    func openItem(path: String) -> ActionResult {
        let url: URL
        if path.hasPrefix("/") || path.hasPrefix("~") {
            let expanded = NSString(string: path).expandingTildeInPath
            url = URL(fileURLWithPath: expanded)
        } else {
            // Treat as app name — find it
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: path) {
                url = appURL
            } else {
                let appPath = "/Applications/\(path).app"
                if FileManager.default.fileExists(atPath: appPath) {
                    url = URL(fileURLWithPath: appPath)
                } else {
                    let sysPath = "/System/Applications/\(path).app"
                    if FileManager.default.fileExists(atPath: sysPath) {
                        url = URL(fileURLWithPath: sysPath)
                    } else {
                        return ActionResult(success: false, output: "Could not find \"\(path)\"")
                    }
                }
            }
        }

        let success = NSWorkspace.shared.open(url)
        if success {
            return ActionResult(success: true, output: "Opened \(url.lastPathComponent)")
        } else {
            return ActionResult(success: false, output: "Failed to open \(url.path)")
        }
    }

    // MARK: - Save Note (agent memory about the user)

    private var notesPath: String { NSHomeDirectory() + "/.lookout/notes.md" }

    func saveNote(note: String) -> ActionResult {
        let dir = NSHomeDirectory() + "/.lookout"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "- [\(timestamp)] \(note)\n"

        if FileManager.default.fileExists(atPath: notesPath),
           let handle = FileHandle(forWritingAtPath: notesPath) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8)!)
            handle.closeFile()
        } else {
            let header = "# Lookout Notes\n\nThings I've learned about this user.\n\n"
            try? (header + entry).write(toFile: notesPath, atomically: true, encoding: .utf8)
        }

        return ActionResult(success: true, output: "Note saved.")
    }

    func readNotes() -> ActionResult {
        guard FileManager.default.fileExists(atPath: notesPath),
              let content = try? String(contentsOfFile: notesPath, encoding: .utf8) else {
            return ActionResult(success: true, output: "No notes yet.")
        }
        return ActionResult(success: true, output: content)
    }

    // MARK: - Dispatch

    func execute(toolName: String, input: [String: Any]) async -> ActionResult {
        switch toolName {
        case "capture_screen":
            return await captureScreen()
        case "list_applications":
            return listApplications()
        case "search_files":
            let query = input["query"] as? String ?? ""
            let directory = input["directory"] as? String
            return searchFiles(query: query, directory: directory)
        case "open_item":
            let path = input["path"] as? String ?? ""
            return openItem(path: path)
        case "save_note":
            let note = input["note"] as? String ?? ""
            return saveNote(note: note)
        case "read_notes":
            return readNotes()
        default:
            return ActionResult(success: false, output: "Unknown tool: \(toolName)")
        }
    }
}
