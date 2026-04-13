import AppKit
import ScreenCaptureKit

final class ScreenCaptureService {

    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// Capture all connected displays as JPEG data.
    /// Each display becomes a separate image. Our own app windows are excluded.
    func captureAllDisplays() async -> [Data] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            guard !content.displays.isEmpty else { return [] }

            let myBundleID = Bundle.main.bundleIdentifier ?? ""
            let excludedWindows = content.windows.filter {
                $0.owningApplication?.bundleIdentifier == myBundleID
            }

            var screenshots: [Data] = []

            for display in content.displays {
                let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
                let config = SCStreamConfiguration()
                config.width = display.width
                config.height = display.height
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = true

                if let cgImage = try? await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                ) {
                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                    if let jpegData = bitmapRep.representation(
                        using: .jpeg,
                        properties: [.compressionFactor: 0.7]
                    ) {
                        screenshots.append(jpegData)
                    }
                }
            }

            return screenshots
        } catch {
            return []
        }
    }
}
