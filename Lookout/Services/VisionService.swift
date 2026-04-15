import AppKit
import Vision

/// Uses Apple Vision framework to find text and UI elements on screen.
final class VisionService {

    struct FoundElement {
        let text: String
        let bounds: CGRect  // In screen coordinates (origin bottom-left)
        let confidence: Float
    }

    /// Find all text on screen using OCR, return matches for the query.
    func findText(matching query: String, in screenshot: Data) -> [FoundElement] {
        guard let image = NSImage(data: screenshot),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return [] }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        var results: [FoundElement] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let queryLower = query.lowercased()

            for obs in observations {
                guard let candidate = obs.topCandidates(1).first else { continue }
                let text = candidate.string

                // Check if this text matches the query (fuzzy)
                if text.lowercased().contains(queryLower) ||
                   queryLower.contains(text.lowercased()) ||
                   Self.fuzzyMatch(text: text.lowercased(), query: queryLower) {

                    // Convert normalized Vision coordinates to pixel coordinates
                    let box = obs.boundingBox
                    let screenBounds = CGRect(
                        x: box.origin.x * imageWidth,
                        y: box.origin.y * imageHeight,
                        width: box.size.width * imageWidth,
                        height: box.size.height * imageHeight
                    )

                    results.append(FoundElement(
                        text: text,
                        bounds: screenBounds,
                        confidence: candidate.confidence
                    ))
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        semaphore.wait()

        // Sort by confidence, best match first
        return results.sorted { $0.confidence > $1.confidence }
    }

    /// Simple fuzzy matching — checks if words overlap significantly.
    private static func fuzzyMatch(text: String, query: String) -> Bool {
        let textWords = Set(text.split(separator: " ").map(String.init))
        let queryWords = Set(query.split(separator: " ").map(String.init))
        let overlap = textWords.intersection(queryWords)
        return !overlap.isEmpty && overlap.count >= queryWords.count / 2
    }

    /// Find the center point of a text element on screen.
    /// Returns screen coordinates (origin top-left, like macOS screen coords).
    func findElementCenter(matching query: String, in screenshot: Data, screenHeight: CGFloat) -> (point: NSPoint, label: String)? {
        let matches = findText(matching: query, in: screenshot)
        guard let best = matches.first else { return nil }

        // Vision coordinates have origin at bottom-left
        // Convert to screen coordinates (origin top-left)
        let centerX = best.bounds.midX
        let centerY = screenHeight - best.bounds.midY  // Flip Y

        return (NSPoint(x: centerX, y: centerY), best.text)
    }
}
