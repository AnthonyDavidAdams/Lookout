import Foundation

/// Reads custom user context from ~/.lookout/context.md
final class CustomContextService {

    private let contextPath: String

    init() {
        self.contextPath = NSHomeDirectory() + "/.lookout/context.md"
    }

    /// Read the user's custom context file, stripping markdown comments and blanks.
    func loadContext() -> String? {
        guard FileManager.default.fileExists(atPath: contextPath) else { return nil }
        guard let raw = try? String(contentsOfFile: contextPath, encoding: .utf8) else { return nil }

        // Strip lines that are just markdown heading markers or example placeholders
        let lines = raw.components(separatedBy: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Skip empty lines, headings, and example lines
                if trimmed.isEmpty { return false }
                if trimmed.hasPrefix("# ") { return false }
                if trimmed.hasPrefix("Examples:") { return false }
                if trimmed.hasPrefix("- \"") { return false }
                if trimmed.hasPrefix("Delete the examples") { return false }
                return true
            }

        let content = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }

    /// Ensure the context directory and template file exist.
    static func ensureContextFile() {
        let dir = NSHomeDirectory() + "/.lookout"
        let file = dir + "/context.md"

        if !FileManager.default.fileExists(atPath: file) {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let template = """
                # Lookout Custom Context

                Add any personal context here that Lookout should know about you.
                This file is included in every conversation to help Lookout give
                you better, more personalized answers.

                Examples:
                - "I'm not very technical, please explain things simply"
                - "I use a Mac for graphic design with Adobe Creative Suite"
                - "I'm a developer, you can use technical terms"
                - "My name is [name], I work at [company]"

                Delete the examples above and write your own context below:

                """
            try? template.write(toFile: file, atomically: true, encoding: .utf8)
        }
    }
}
