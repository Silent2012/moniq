#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
SWIFTC="/usr/bin/swiftc"
PYTHON="/Library/Frameworks/Python.framework/Versions/3.14/bin/python3"
APP_NAME="moniq"
APP_BUNDLE="$ROOT/$APP_NAME.app"
TMP="$ROOT/.build_tmp"

SOURCES=(
    "Utilities/AppTheme.swift"
    "Utilities/DesignSystem.swift"
    "Utilities/Extensions.swift"
    "Utilities/Formatters.swift"
    "Utilities/Constants.swift"
    "Core/Models.swift"
    "Core/SystemMonitor.swift"
    "Core/BatteryMonitor.swift"
    "Core/NetworkMonitor.swift"
    "Core/DiskMonitor.swift"
    "Core/AppUsageTracker.swift"
    "Core/AnalyticsRecorder.swift"
    "ViewModels/DashboardViewModel.swift"
    "ViewModels/AppUsageViewModel.swift"
    "ViewModels/SettingsViewModel.swift"
    "Views/Components/GlowingCard.swift"
    "Views/Components/AnimatedRing.swift"
    "Views/Components/SparklineView.swift"
    "Views/Components/AnimatedNumber.swift"
    "Views/Components/StatusDot.swift"
    "Views/Sidebar/SidebarView.swift"
    "Views/Dashboard/HeroMetricsRow.swift"
    "Views/Dashboard/CPUDetailCard.swift"
    "Views/Dashboard/MemoryRingCard.swift"
    "Views/Dashboard/NetworkCard.swift"
    "Views/Dashboard/TopProcessesTable.swift"
    "Views/Dashboard/DashboardView.swift"
    "Views/AppUsage/AppRowItem.swift"
    "Views/AppUsage/AppDetailPanel.swift"
    "Views/AppUsage/AppUsageView.swift"
    "Views/Analytics/TimelineChart.swift"
    "Views/Analytics/HeatmapView.swift"
    "Views/Analytics/AnalyticsView.swift"
    "Views/Battery/BatteryView.swift"
    "Views/Settings/SettingsView.swift"
    "Views/MenuBar/MenuBarPopoverView.swift"
    "ContentView.swift"
    "App/AppDelegate.swift"
    "App/moniqApp.swift"
)

echo "🔨 Building moniq.app…"

# ── Preprocess: strip #Preview blocks (require Xcode plugin, unavailable in CLI) ──
rm -rf "$TMP" && mkdir -p "$TMP"

strip_previews() {
"$PYTHON" - "$1" "$2" << 'PYEOF'
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    lines = f.readlines()

out = []
depth = 0   # brace depth inside a #Preview block (0 = not in one)
for line in lines:
    stripped = line.lstrip()
    if depth == 0 and stripped.startswith('#Preview'):
        depth = line.count('{') - line.count('}')
        continue
    if depth > 0:
        depth += line.count('{') - line.count('}')
        if depth <= 0:
            depth = 0
        continue
    out.append(line)

import os
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, 'w') as f:
    f.writelines(out)
PYEOF
}

PROCESSED=()
for rel in "${SOURCES[@]}"; do
    src="$ROOT/$rel"
    dst="$TMP/$rel"
    strip_previews "$src" "$dst"
    PROCESSED+=("$dst")
done

# ── Create .app bundle ──
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy app icon
cp "$ROOT/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.moniq.app</string>
    <key>CFBundleName</key>
    <string>moniq</string>
    <key>CFBundleDisplayName</key>
    <string>moniq</string>
    <key>CFBundleExecutable</key>
    <string>moniq</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2024 moniq</string>
</dict>
</plist>
PLIST

# ── Compile ──
"$SWIFTC" \
    -sdk "$SDK" \
    -target arm64-apple-macosx13.0 \
    -parse-as-library \
    -O \
    -framework AppKit \
    -framework SwiftUI \
    -framework Foundation \
    -framework IOKit \
    -framework Network \
    -framework Charts \
    -framework ServiceManagement \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    "${PROCESSED[@]}"

# ── Ad-hoc sign so Gatekeeper allows launch ──
codesign --force --deep --sign - "$APP_BUNDLE"

rm -rf "$TMP"

# ── Install to ~/Applications so Spotlight indexes it ──
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_NAME.app"

# Re-sign the installed copy (paths changed)
codesign --force --deep --sign - "$INSTALL_DIR/$APP_NAME.app"

# Register with Launch Services so Spotlight finds it immediately
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME.app"

echo "✅  Built and installed $INSTALL_DIR/$APP_NAME.app"
echo "   Run: open \"$INSTALL_DIR/$APP_NAME.app\""
