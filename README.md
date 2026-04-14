<p align="center">
  <img src="assets/icon_1024.png" alt="Lookout" width="128">
</p>

<h1 align="center">Lookout</h1>

<p align="center">
  <strong>AI screen assistant for macOS</strong><br>
  Sees your screen. Helps you navigate. Takes action.
</p>

<p align="center">
  <img src="assets/demo.gif" alt="Lookout Demo" width="300">
</p>

---

## 🧭 About

Every day, people call their kids, coworkers, or IT help desk to ask *"how do I do this on my computer?"* They're staring at the screen, trying to describe what they see, while someone on the other end guesses what they're looking at.

**Lookout was inspired by helping parents and co-workers with their computers.** Instead of a phone call where you're both guessing, Lookout can actually *see* the screen and give specific, contextual guidance — "Click the blue Save button in the top-right corner" instead of "there should be a button somewhere."

It's like a knowledgeable friend looking over your shoulder.

## ✨ Features

| | Feature | Details |
|---|---|---|
| 👁️ | **Screen Vision** | Captures all connected displays via ScreenCaptureKit |
| 🧠 | **Context Aware** | Knows what apps are running, what windows are open |
| 🎯 | **Specific Guidance** | References actual buttons, menus, and text it can see |
| 🛠️ | **Takes Action** | Opens apps, finds files, searches your Mac |
| ⚡ | **Streaming** | Responses appear in real-time as they're generated |
| 📸 | **Smart Capture** | Auto-screenshots on first message or after inactivity; on-demand tool for follow-ups |
| 💬 | **Long Conversations** | Strips old images, auto-summarizes history to stay in context |
| 🧑‍💻 | **Personalizable** | Custom context via `~/.lookout/context.md` |
| 📝 | **Memory** | Saves notes about you across sessions for better help over time |

## 🚀 Install

```bash
git clone https://github.com/AnthonyDavidAdams/Lookout.git
cd Lookout
./install.sh
```

> Builds the app, installs to `/Applications`, creates your config, and offers to launch.

Or build manually: `./build.sh && open Lookout.app`

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)
- A [Claude API key](https://console.anthropic.com)

### First Run

1. Click the **eye icon** in your menu bar
2. Enter your Claude API key
3. Grant **Screen Recording** when prompted
4. Ask anything about your screen

## 🎨 Personalize

Edit `~/.lookout/context.md` to tell Lookout about yourself:

```
I'm not very technical, please explain things simply.
I use my Mac for photo editing with Lightroom and Photoshop.
My name is Mom.
```

Or edit directly in the app: **right-click menu bar icon → Settings → Context tab**

Lookout also learns about you over time — it saves notes about what you work on, what you struggle with, and your preferences in `~/.lookout/notes.md`.

## 💡 Usage

| Action | How |
|---|---|
| Toggle panel | **Left-click** menu bar eye icon |
| Menu | **Right-click** menu bar icon |
| Move panel | Drag anywhere |
| Close | Click the X or left-click the icon |

### Example Questions

> "What apps do I have open?"
> "How do I change my wallpaper?"
> "Can you find my recent PDFs?"
> "Open Safari for me"
> "I'm trying to export this document — where's the export button?"

## 🔧 How It Works

Pure Swift, zero dependencies. Built with:

- **SwiftUI** — floating chat panel
- **ScreenCaptureKit** — multi-display capture (excludes own window)
- **Claude API** — vision + tool use with streaming responses
- **NSPanel** — non-activating floating window

### Tools Available to the AI

| Tool | What it does |
|---|---|
| `capture_screen` | Take a fresh screenshot of all displays |
| `list_applications` | See what's installed on the Mac |
| `search_files` | Spotlight search for files and folders |
| `open_item` | Open any app, file, or folder |
| `save_note` | Remember something about the user |
| `read_notes` | Recall notes from previous sessions |

### Architecture

```
Lookout/
├── install.sh                        # One-click installer
├── build.sh                          # Build from source
└── Lookout/
    ├── LookoutApp.swift              # Entry point
    ├── AppDelegate.swift             # Menu bar + panel
    ├── FloatingPanel.swift           # NSPanel subclass
    ├── Models/Message.swift
    ├── Views/
    │   ├── ChatView.swift            # Chat interface
    │   ├── MessageView.swift         # Markdown message bubbles
    │   └── SettingsView.swift        # API key + context editor
    └── Services/
        ├── ScreenCaptureService.swift      # Multi-display capture
        ├── ClaudeAPIService.swift          # Streaming + tool use
        ├── ConversationManager.swift       # History + summarization
        ├── SystemContextService.swift      # Running apps + windows
        ├── CustomContextService.swift      # ~/.lookout/context.md
        └── ActionService.swift             # Tool implementations
```

## 📄 License

[CC BY-NC 4.0](LICENSE) — free for non-commercial use with attribution.

---

<p align="center">
  Provided as a public utility by
  <a href="https://earthpilot.org"><img src="assets/earthpilot-logo.png" alt="Earth Pilot" width="18" height="18" style="vertical-align: middle;"></a>
  <a href="https://earthpilot.org"><strong>Earth Pilot</strong></a> — Mission Support for Spaceship Earth.
</p>
