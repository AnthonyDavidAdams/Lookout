import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var overlayWindow: OverlayWindow!
    let conversationManager = ConversationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupOverlay()
        setupPanel()
        setupMenuBar()

        // Ensure ~/.lookout/context.md exists
        CustomContextService.ensureContextFile()

        // Prompt for screen recording permission if not yet granted
        if !ScreenCaptureService.hasPermission {
            ScreenCaptureService.requestPermission()
        }

        // Show panel on launch
        showPanel()
    }

    // MARK: - Overlay

    private func setupOverlay() {
        overlayWindow = OverlayWindow()

        // Wire the highlight callback from ActionService
        conversationManager.onHighlight = { [weak self] point, radius, label in
            self?.overlayWindow.showHighlight(at: point, radius: radius, label: label)
        }
    }

    // MARK: - Panel

    private func setupPanel() {
        let chatView = ChatView()
            .environmentObject(conversationManager)
        let hostingView = NSHostingView(rootView: chatView)
        panel = FloatingPanel(contentView: hostingView)
    }

    private func showPanel() {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        button.image = NSImage(
            systemSymbolName: "eye.circle",
            accessibilityDescription: "Lookout"
        )
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            togglePanel()
        }
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: panel.isVisible ? "Hide Lookout" : "Show Lookout",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let newItem = NSMenuItem(
            title: "New Conversation",
            action: #selector(newConversation),
            keyEquivalent: "n"
        )
        newItem.target = self
        menu.addItem(newItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Lookout",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func newConversation() {
        conversationManager.clearConversation()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
