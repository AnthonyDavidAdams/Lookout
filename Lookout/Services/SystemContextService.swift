import AppKit
import ScreenCaptureKit

struct SystemContext {
    let runningApps: [AppInfo]
    let frontmostApp: String?
    let windowTitles: [String]

    struct AppInfo {
        let name: String
        let bundleID: String?
    }

    /// Formatted context string to include with the user's message to Claude.
    var description: String {
        var parts: [String] = []

        if let front = frontmostApp {
            parts.append("Frontmost app: \(front)")
        }

        let appNames = runningApps.map(\.name).joined(separator: ", ")
        parts.append("Running apps: \(appNames)")

        if !windowTitles.isEmpty {
            parts.append("Visible windows:\n" + windowTitles.map { "  - \($0)" }.joined(separator: "\n"))
        }

        return parts.joined(separator: "\n")
    }
}

final class SystemContextService {

    /// Gather running apps and visible window titles.
    func gatherContext() async -> SystemContext {
        let workspace = NSWorkspace.shared

        // Running user-facing apps
        let apps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> SystemContext.AppInfo? in
                guard let name = app.localizedName else { return nil }
                return SystemContext.AppInfo(name: name, bundleID: app.bundleIdentifier)
            }

        let frontmost = workspace.frontmostApplication?.localizedName

        // Visible window titles via ScreenCaptureKit
        var windowTitles: [String] = []
        let myBundleID = Bundle.main.bundleIdentifier ?? ""

        if let content = try? await SCShareableContent.excludingDesktopWindows(
            true, onScreenWindowsOnly: true
        ) {
            for window in content.windows {
                guard let title = window.title, !title.isEmpty,
                      window.owningApplication?.bundleIdentifier != myBundleID
                else { continue }

                let appName = window.owningApplication?.applicationName ?? "Unknown"
                windowTitles.append("\(appName) — \(title)")
            }
        }

        return SystemContext(
            runningApps: apps,
            frontmostApp: frontmost,
            windowTitles: windowTitles
        )
    }
}
