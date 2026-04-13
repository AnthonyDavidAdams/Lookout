# Lookout

An AI screen assistant for macOS. Lookout sees your screen and helps you navigate your computer — like a knowledgeable friend looking over your shoulder.

<p align="center">
  <img src="assets/demo.gif" alt="Lookout Demo" width="300">
</p>

## Why

Every day, people call their kids, coworkers, or IT help desk to ask "how do I do this on my computer?" They're staring at the screen, trying to describe what they see, while someone on the other end guesses what they're looking at.

Lookout was inspired by helping parents and co-workers with their computers. Instead of a phone call where you're both guessing, Lookout can actually see the screen and give specific, contextual guidance: "Click the blue Save button in the top-right corner" instead of "there should be a button somewhere."

## What it does

- **Sees your screen** — captures all connected displays via ScreenCaptureKit
- **Understands context** — knows what apps are running, what windows are open
- **Gives specific guidance** — references actual buttons, menus, and text it can see
- **Takes action** — can open apps, find files, and search your Mac
- **Streams responses** — answers appear in real-time as they're generated
- **Smart about screenshots** — auto-captures at the start or after inactivity, uses a tool for on-demand captures (saves tokens on conversational follow-ups)
- **Manages long conversations** — strips old images and auto-summarizes history to stay within context limits
- **Personalizable** — add custom context in `~/.lookout/context.md` so it knows who you are

## Install

One command:

```bash
git clone https://github.com/AnthonyDavidAdams/Lookout.git
cd Lookout
./install.sh
```

This builds the app, installs it to `/Applications`, creates your config file, and offers to launch it.

Or build manually:

```bash
./build.sh
open Lookout.app
```

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)
- A [Claude API key](https://console.anthropic.com)

### First run

1. Click the **eye icon** in your menu bar
2. Enter your Claude API key
3. Grant **Screen Recording** permission when prompted
4. Ask anything about your screen

## Personalize

Edit `~/.lookout/context.md` to add context about yourself:

```markdown
I'm not very technical, please explain things simply.
I use my Mac for photo editing with Lightroom and Photoshop.
My name is Mom.
```

This is included in every conversation so Lookout tailors its responses to you.

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
├── install.sh                   # One-click installer
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
        ├── CustomContextService.swift    # ~/.lookout/context.md reader
        └── ActionService.swift           # Tool implementations
```

## License

[CC BY-NC 4.0](LICENSE) — free for non-commercial use with attribution.
