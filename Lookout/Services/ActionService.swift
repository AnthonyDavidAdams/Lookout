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

    // MARK: - Highlight Element on Screen

    private let visionService = VisionService()

    /// Callback to show overlay — set by ConversationManager
    var onHighlight: ((NSPoint, CGFloat, String?) -> Void)?

    func highlightElement(textToFind: String, label: String?) async -> ActionResult {
        // Capture a fresh screenshot to search in
        let screenshots = await screenCapture.captureAllDisplays()
        guard let screenshot = screenshots.first else {
            return ActionResult(success: false, output: "Could not capture screen to search for element.")
        }

        guard let screen = await MainActor.run(body: { NSScreen.main }) else {
            return ActionResult(success: false, output: "No screen available.")
        }
        let screenHeight = await MainActor.run { screen.frame.height }

        // Use Vision OCR to find the text
        guard let found = visionService.findElementCenter(
            matching: textToFind,
            in: screenshot,
            screenHeight: screenHeight
        ) else {
            return ActionResult(
                success: false,
                output: "Could not find \"\(textToFind)\" on screen. It may not be visible or the text doesn't match exactly."
            )
        }

        // Show overlay on main thread
        let displayLabel = label ?? found.label
        await MainActor.run {
            onHighlight?(found.point, 25, displayLabel)
        }

        // Also crop the area around the found element and return as image
        let cropSize: CGFloat = 200
        let cropX = max(0, found.point.x - cropSize / 2)
        let cropY = max(0, (screenHeight - found.point.y) - cropSize / 2)  // Flip back for image coords

        if let nsImage = NSImage(data: screenshot),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let imgW = CGFloat(cgImage.width)
            let imgH = CGFloat(cgImage.height)
            let cropRect = CGRect(
                x: min(cropX, imgW - cropSize),
                y: min(cropY, imgH - cropSize),
                width: min(cropSize, imgW),
                height: min(cropSize, imgH)
            )
            if let cropped = cgImage.cropping(to: cropRect) {
                // Draw a highlight circle on the cropped image
                let croppedImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
                let highlighted = drawHighlightCircle(on: croppedImage)
                if let tiffData = highlighted.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                    return ActionResult(
                        success: true,
                        output: "Found \"\(found.label)\" on screen and highlighted it. The arrow on your screen points to it.",
                        images: [jpegData]
                    )
                }
            }
        }

        return ActionResult(success: true, output: "Found \"\(found.label)\" and highlighted it on your screen with an arrow.")
    }

    private func drawHighlightCircle(on image: NSImage) -> NSImage {
        let result = NSImage(size: image.size)
        result.lockFocus()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)

        let ctx = NSGraphicsContext.current!.cgContext
        let cx = image.size.width / 2
        let cy = image.size.height / 2
        let r: CGFloat = min(image.size.width, image.size.height) * 0.3

        ctx.setStrokeColor(NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.9).cgColor)
        ctx.setLineWidth(4)
        ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

        result.unlockFocus()
        return result
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
        case "highlight_element":
            let text = input["text_to_find"] as? String ?? ""
            let label = input["label"] as? String
            return await highlightElement(textToFind: text, label: label)
        default:
            return ActionResult(success: false, output: "Unknown tool: \(toolName)")
        }
    }
}
