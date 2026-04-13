# Lookout

An AI screen assistant for macOS. Lookout sees your screen and helps you navigate your computer — like a knowledgeable friend looking over your shoulder.

<p align="center">
  <img src="assets/demo.gif" alt="Lookout Demo" width="300">
</p>

## Why

Every day, people call their kids, coworkers, or IT help desk to ask "how do I do this on my computer?" They're staring at the screen, trying to describe what they see, while someone on the other end guesses what they're looking at.

Lookout was inspired by helping mothers and co-workers with their computers. Instead of a phone call where you're both guessing, Lookout can actually see the screen and give specific, contextual guidance: "Click the blue Save button in the top-right corner" instead of "there should be a button somewhere."

## What it does

- **Sees your screen** — captures all connected displays via ScreenCaptureKit
- **Understands context** — knows what apps are running, what windows are open
- **Gives specific guidance** — references actual buttons, menus, and text it can see
- **Takes action** — can open apps, find files, and search your Mac
- **Streams responses** — answers appear in real-time as they're generated
- **Smart about screenshots** — auto-captures at the start or after inactivity, uses a tool for on-demand captures (saves tokens on conversational follow-ups)
- **Manages long conversations** — strips old images and auto-summarizes history to stay within context limits

## Setup

### Prerequisites

- macOS 14 (Sonoma) or later
- [Homebrew](https://brew.sh)
- A [Claude API key](https://console.anthropic.com)

### Build

```bash
git clone https://github.com/AnthonyDavidAdams/Lookout.git
cd Lookout
chmod +x build.sh
./build.sh
```

Or if you prefer Xcode:

```bash
chmod +x setup.sh
./setup.sh        # installs xcodegen if needed, generates .xcodeproj
open Lookout.xcodeproj
# Build & Run (Cmd+R)
```

### First run

1. Launch `Lookout.app`
2. Click the **eye icon** in your menu bar
3. Enter your Claude API key (or set it in Settings)
4. Grant **Screen Recording** permission when prompted
5. Ask anything about your screen

## Usage

- **Left-click** menu bar icon to toggle the chat panel
- **Right-click** for menu (New Conversation, Settings, Quit)
- The panel floats above other windows — drag it anywhere

### Example questions

- "What apps do I have open?"
- "How do I change my wallpaper?"
- "Can you find my recent PDFs?"
- "Open Safari for me"
- "I'm trying to export this document — where's the export button?"

## Architecture

Pure Swift, no dependencies. Built with:

- **SwiftUI** — chat interface
- **ScreenCaptureKit** — screen capture (excludes own window)
- **Claude API** — vision + tool use with streaming
- **NSPanel** — floating, non-activating window

### Tools available to the AI

| Tool | Description |
|------|-------------|
| `capture_screen` | Take a fresh screenshot of all displays |
| `list_applications` | List installed apps |
| `search_files` | Spotlight search for files and folders |
| `open_item` | Open an app, file, or folder |

## Project structure

```
Lookout/
├── build.sh                     # Build script (no Xcode needed)
├── setup.sh                     # Xcode project generator
├── project.yml                  # xcodegen spec
└── Lookout/
    ├── LookoutApp.swift         # App entry point
    ├── AppDelegate.swift        # Menu bar + panel management
    ├── FloatingPanel.swift      # NSPanel subclass
    ├── Models/
    │   └── Message.swift
    ├── Views/
    │   ├── ChatView.swift       # Main chat interface
    │   ├── MessageView.swift    # Message bubbles with markdown
    │   └── SettingsView.swift
    └── Services/
        ├── ScreenCaptureService.swift    # Multi-display capture
        ├── ClaudeAPIService.swift        # Streaming + tool use
        ├── ConversationManager.swift     # State, history, summarization
        ├── SystemContextService.swift    # Running apps + window titles
        └── ActionService.swift           # Tool implementations
```

## License

[CC BY-NC 4.0](LICENSE) — free for non-commercial use with attribution.
