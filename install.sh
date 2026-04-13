#!/bin/bash
set -e

echo ""
echo "  ┌──────────────────────────┐"
echo "  │   Lookout Installer      │"
echo "  │   AI Screen Assistant    │"
echo "  └──────────────────────────┘"
echo ""

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check macOS version
sw_vers_major=$(sw_vers -productVersion | cut -d. -f1)
if [ "$sw_vers_major" -lt 14 ]; then
    echo "Error: Lookout requires macOS 14 (Sonoma) or later."
    echo "You're running $(sw_vers -productVersion)."
    exit 1
fi

# Check for Swift compiler
if ! command -v swiftc &>/dev/null; then
    echo "Error: Swift compiler not found."
    echo "Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

# Build
echo "Building Lookout..."
"$BUILD_DIR/build.sh" > /dev/null 2>&1

# Create custom context file if it doesn't exist
CONTEXT_DIR="$HOME/.lookout"
CONTEXT_FILE="$CONTEXT_DIR/context.md"
if [ ! -f "$CONTEXT_FILE" ]; then
    mkdir -p "$CONTEXT_DIR"
    cat > "$CONTEXT_FILE" << 'MD'
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

MD
    echo "Created ~/.lookout/context.md — edit this to personalize Lookout."
fi

# Install to /Applications
echo "Installing to /Applications..."
if [ -d "/Applications/Lookout.app" ]; then
    rm -rf "/Applications/Lookout.app"
fi
cp -r "$BUILD_DIR/Lookout.app" /Applications/

# Clear icon cache so the new icon shows
touch /Applications/Lookout.app

echo ""
echo "Installed! Lookout is in your Applications folder."
echo ""
echo "To launch:  open /Applications/Lookout.app"
echo ""
echo "First time setup:"
echo "  1. Click the eye icon in your menu bar"
echo "  2. Enter your Claude API key (console.anthropic.com)"
echo "  3. Grant Screen Recording when prompted"
echo "  4. Ask anything about your screen!"
echo ""
echo "Personalize: edit ~/.lookout/context.md"
echo ""

# Offer to launch
read -p "Launch Lookout now? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    open /Applications/Lookout.app
fi
