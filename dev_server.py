#!/usr/bin/env python3
"""
moniq dev server — live build-status dashboard.
Serves a status page on http://localhost:3333 and runs swiftc -typecheck
in the background whenever source files change.
"""

import http.server
import subprocess
import threading
import time
import os
import json
from datetime import datetime

PORT = 3333
ROOT = os.path.dirname(os.path.abspath(__file__))
SDK  = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
SWIFTC = "/usr/bin/swiftc"

SWIFT_SOURCES = [
    "Utilities/DesignSystem.swift", "Utilities/Extensions.swift",
    "Utilities/Formatters.swift", "Utilities/Constants.swift",
    "Core/Models.swift", "Core/SystemMonitor.swift",
    "Core/BatteryMonitor.swift", "Core/NetworkMonitor.swift",
    "Core/DiskMonitor.swift", "Core/AppUsageTracker.swift",
    "ViewModels/DashboardViewModel.swift", "ViewModels/AppUsageViewModel.swift",
    "ViewModels/SettingsViewModel.swift",
    "Views/Components/GlowingCard.swift", "Views/Components/AnimatedRing.swift",
    "Views/Components/SparklineView.swift", "Views/Components/AnimatedNumber.swift",
    "Views/Components/StatusDot.swift", "Views/Sidebar/SidebarView.swift",
    "Views/Dashboard/HeroMetricsRow.swift", "Views/Dashboard/CPUDetailCard.swift",
    "Views/Dashboard/MemoryRingCard.swift", "Views/Dashboard/NetworkCard.swift",
    "Views/Dashboard/TopProcessesTable.swift", "Views/Dashboard/DashboardView.swift",
    "Views/AppUsage/AppRowItem.swift", "Views/AppUsage/AppDetailPanel.swift",
    "Views/AppUsage/AppUsageView.swift", "Views/Analytics/TimelineChart.swift",
    "Views/Analytics/HeatmapView.swift", "Views/Analytics/AnalyticsView.swift",
    "Views/Battery/BatteryView.swift", "Views/Settings/SettingsView.swift",
    "Views/MenuBar/MenuBarPopoverView.swift", "ContentView.swift",
    "App/AppDelegate.swift", "App/moniqApp.swift",
]

# Shared state
state = {
    "status": "idle",          # idle | checking | ok | error
    "output": "Initialising…",
    "errors": 0,
    "warnings": 0,
    "checked_at": None,
    "duration_ms": 0,
    "file_count": len(SWIFT_SOURCES),
}
state_lock = threading.Lock()


# ── Type-checker ─────────────────────────────────────────────────────────────

def run_typecheck():
    start = time.time()
    with state_lock:
        state["status"] = "checking"
        state["output"] = "Running swiftc -typecheck…"

    cmd = [SWIFTC, "-typecheck",
           "-sdk", SDK,
           "-target", "arm64-apple-macosx13.0",
           "-framework", "AppKit", "-framework", "SwiftUI",
           "-framework", "Foundation", "-framework", "IOKit",
           "-framework", "Network"] + SWIFT_SOURCES

    result = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    elapsed = int((time.time() - start) * 1000)

    combined = (result.stdout + result.stderr).strip()
    real_errors   = [l for l in combined.splitlines() if "error:"   in l and "PreviewsMacros" not in l and "SwiftUIView" not in l]
    warnings      = [l for l in combined.splitlines() if "warning:" in l]

    with state_lock:
        state["status"]      = "ok" if not real_errors else "error"
        state["errors"]      = len(real_errors)
        state["warnings"]    = len(warnings)
        state["output"]      = "\n".join(real_errors + warnings) if (real_errors or warnings) else "✅  No errors"
        state["checked_at"]  = datetime.now().strftime("%H:%M:%S")
        state["duration_ms"] = elapsed


# ── File watcher ─────────────────────────────────────────────────────────────

def watch_loop():
    mtimes = {}
    while True:
        changed = False
        for rel in SWIFT_SOURCES:
            path = os.path.join(ROOT, rel)
            try:
                mt = os.path.getmtime(path)
                if mtimes.get(rel) != mt:
                    mtimes[rel] = mt
                    changed = True
            except FileNotFoundError:
                pass
        if changed:
            run_typecheck()
        time.sleep(2)


# ── HTTP handler ─────────────────────────────────────────────────────────────

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="4">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>moniq — dev server</title>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: #0A0A0F; color: #fff; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif; padding: 32px; }}
  h1 {{ background: linear-gradient(90deg,#6C63FF,#00D4FF); -webkit-background-clip: text; -webkit-text-fill-color: transparent; font-size: 28px; margin-bottom: 4px; }}
  .sub {{ color: #8B8BA7; font-size: 13px; margin-bottom: 32px; }}
  .card {{ background: #111118; border: 1px solid #2A2A3A; border-radius: 16px; padding: 24px; margin-bottom: 20px; }}
  .status {{ display: flex; align-items: center; gap: 12px; }}
  .dot {{ width: 12px; height: 12px; border-radius: 50%; flex-shrink: 0; }}
  .dot.ok {{ background: #00FF88; box-shadow: 0 0 8px #00FF8888; }}
  .dot.error {{ background: #FF4757; box-shadow: 0 0 8px #FF475788; animation: pulse 1s infinite; }}
  .dot.checking {{ background: #FFB830; box-shadow: 0 0 8px #FFB83088; animation: pulse 0.8s infinite; }}
  .dot.idle {{ background: #4A4A6A; }}
  @keyframes pulse {{ 0%,100% {{ opacity:1; }} 50% {{ opacity:0.4; }} }}
  .label {{ font-size: 20px; font-weight: 600; }}
  .meta {{ color: #8B8BA7; font-size: 12px; margin-top: 4px; }}
  .pills {{ display: flex; gap: 10px; margin-top: 16px; }}
  .pill {{ padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; }}
  .pill.err {{ background: #FF475720; color: #FF4757; border: 1px solid #FF475740; }}
  .pill.warn {{ background: #FFB83020; color: #FFB830; border: 1px solid #FFB83040; }}
  .pill.ok {{ background: #00FF8820; color: #00FF88; border: 1px solid #00FF8840; }}
  pre {{ background: #0A0A0F; border-radius: 8px; padding: 16px; font-size: 11px; line-height: 1.6; color: #FF4757; overflow-x: auto; white-space: pre-wrap; word-break: break-all; margin-top: 16px; border: 1px solid #2A2A3A; max-height: 400px; overflow-y: auto; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(160px,1fr)); gap: 12px; margin-top: 8px; }}
  .stat {{ background: #0A0A0F; border-radius: 10px; padding: 14px; border: 1px solid #2A2A3A; }}
  .stat-val {{ font-size: 22px; font-weight: 700; font-variant-numeric: tabular-nums; }}
  .stat-lbl {{ color: #8B8BA7; font-size: 11px; margin-top: 2px; }}
</style>
</head>
<body>
<h1>moniq</h1>
<p class="sub">macOS system analytics · Dev server · Auto-refreshes every 4s</p>

<div class="card">
  <div class="status">
    <div class="dot {status_class}"></div>
    <div>
      <div class="label">{status_label}</div>
      <div class="meta">Last check: {checked_at} &nbsp;·&nbsp; {duration_ms}ms &nbsp;·&nbsp; {file_count} files</div>
    </div>
  </div>
  <div class="pills">
    {error_pill}
    {warn_pill}
  </div>
  {output_block}
</div>

<div class="card">
  <div class="meta" style="margin-bottom:14px;font-size:13px;color:#fff;font-weight:600;">Project Stats</div>
  <div class="grid">
    <div class="stat"><div class="stat-val" style="color:#6C63FF">{file_count}</div><div class="stat-lbl">Swift files</div></div>
    <div class="stat"><div class="stat-val" style="color:#00D4FF">13.0+</div><div class="stat-lbl">macOS target</div></div>
    <div class="stat"><div class="stat-val" style="color:#00FF88">5.9</div><div class="stat-lbl">Swift version</div></div>
    <div class="stat"><div class="stat-val" style="color:#FFB830">37</div><div class="stat-lbl">Source files</div></div>
  </div>
</div>

<p style="color:#4A4A6A;font-size:11px;margin-top:8px">
  moniq dev server · http://localhost:{port} · watching for changes every 2s
</p>
</body></html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # suppress access log noise

    def do_GET(self):
        if self.path == "/status":
            with state_lock:
                data = dict(state)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
            return

        with state_lock:
            s = dict(state)

        status_class = s["status"]
        status_label = {
            "ok":       "✅  Type-check passed",
            "error":    f"❌  {s['errors']} error(s) found",
            "checking": "⏳  Checking…",
            "idle":     "Waiting for changes…",
        }.get(s["status"], s["status"])

        error_pill = f'<span class="pill err">{s["errors"]} error{"s" if s["errors"]!=1 else ""}</span>' if s["errors"] else '<span class="pill ok">0 errors</span>'
        warn_pill  = f'<span class="pill warn">{s["warnings"]} warning{"s" if s["warnings"]!=1 else ""}</span>' if s["warnings"] else ""
        output_block = f"<pre>{s['output']}</pre>" if s["output"] and s["output"] != "✅  No errors" else ""

        html = HTML_TEMPLATE.format(
            status_class=status_class,
            status_label=status_label,
            checked_at=s["checked_at"] or "—",
            duration_ms=s["duration_ms"],
            file_count=s["file_count"],
            error_pill=error_pill,
            warn_pill=warn_pill,
            output_block=output_block,
            port=PORT,
        )
        body = html.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    os.chdir(ROOT)

    # Initial type-check in background
    threading.Thread(target=run_typecheck, daemon=True).start()

    # File watcher
    threading.Thread(target=watch_loop, daemon=True).start()

    server = http.server.HTTPServer(("localhost", PORT), Handler)
    print(f"moniq dev server running on http://localhost:{PORT}", flush=True)
    server.serve_forever()
