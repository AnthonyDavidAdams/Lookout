#!/bin/bash
set -e

echo "Setting up Lookout..."
echo ""

# Check for Xcode
if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools required."
    echo "Run: xcode-select --install"
    exit 1
fi

# Install xcodegen if needed
if ! command -v xcodegen &>/dev/null; then
    echo "Installing xcodegen via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "Error: Homebrew is required. Install it from https://brew.sh"
        exit 1
    fi
    brew install xcodegen
fi

# Generate Xcode project
echo "Generating Xcode project..."
cd "$(dirname "$0")"
xcodegen generate

echo ""
echo "Setup complete! Next steps:"
echo ""
echo "  1. Open Lookout.xcodeproj in Xcode"
echo "  2. Build and run (Cmd+R)"
echo "  3. Click the eye icon in your menu bar"
echo "  4. Enter your Claude API key (console.anthropic.com)"
echo "  5. Grant Screen Recording permission when prompted"
echo "  6. Ask anything about your screen!"
echo ""
