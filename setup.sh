#!/bin/bash
# moniq — Xcode project setup script
# Run this from /Users/james/Projects/moniq/

set -e

echo "🔧 Setting up moniq Xcode project..."

# ─── Option A: XcodeGen (recommended if installed) ───
if command -v xcodegen &> /dev/null; then
    echo "✓ XcodeGen found — generating project..."
    xcodegen generate
    echo "✓ moniq.xcodeproj created!"
    echo "  → Open: open moniq.xcodeproj"
    exit 0
fi

# ─── Option B: Install XcodeGen via Homebrew ───
if command -v brew &> /dev/null; then
    echo "Installing XcodeGen via Homebrew..."
    brew install xcodegen
    xcodegen generate
    echo "✓ moniq.xcodeproj created!"
    echo "  → Open: open moniq.xcodeproj"
    exit 0
fi

# ─── Option C: Manual instructions ───
echo ""
echo "══════════════════════════════════════════════════"
echo "  XcodeGen not found. Create the project manually:"
echo "══════════════════════════════════════════════════"
echo ""
echo "1. Open Xcode → File → New → Project"
echo "   • Template: macOS → App"
echo "   • Product Name: moniq"
echo "   • Bundle ID: com.moniq.app"
echo "   • Language: Swift"
echo "   • Interface: SwiftUI"
echo "   • Uncheck: 'Include Tests' (can add later)"
echo ""
echo "2. Save project to: $(pwd)"
echo ""
echo "3. DELETE the auto-generated files:"
echo "   • ContentView.swift (we have ours)"
echo "   • <AppName>App.swift (we have App/moniqApp.swift)"
echo ""
echo "4. ADD all source files: File → Add Files to 'moniq'"
echo "   Add these folders (check 'Create groups'):"
echo "   • App/"
echo "   • Core/"
echo "   • ViewModels/"
echo "   • Views/"
echo "   • Utilities/"
echo "   • ContentView.swift"
echo ""
echo "5. Set deployment target: macOS 13.0+"
echo "   Project Settings → moniq target → General → macOS 13.0"
echo ""
echo "6. Add frameworks (Build Phases → Link Binary With Libraries):"
echo "   • IOKit.framework"
echo "   • Network.framework (usually auto-linked)"
echo ""
echo "7. Set entitlements:"
echo "   Target → Signing & Capabilities → + Capability"
echo "   OR set CODE_SIGN_ENTITLEMENTS = moniq.entitlements in Build Settings"
echo ""
echo "8. Disable sandboxing for full system access:"
echo "   Signing & Capabilities → App Sandbox → REMOVE it"
echo "   (Required for mach host_processor_info and IOKit battery access)"
echo ""
echo "9. Build & Run: ⌘R"
echo ""
echo "══════════════════════════════════════════════════"
echo "  IMPORTANT: Run as your own account, not root."
echo "  System monitoring APIs need no special permissions"
echo "  beyond disabling the sandbox."
echo "══════════════════════════════════════════════════"
