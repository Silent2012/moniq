<div align="center">

# moniq

**A lightweight, real-time system monitor for macOS — lives in your menu bar.**

[![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square&logo=apple)](https://github.com/Silent2012/moniq/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/Silent2012/moniq?style=flat-square&color=6C63FF)](https://github.com/Silent2012/moniq/releases)
[![Free](https://img.shields.io/badge/price-free-00FF88?style=flat-square)]()

[**Download .dmg**](https://github.com/Silent2012/moniq/releases) · [Website](https://silent2012.github.io/moniq) · [Report a bug](https://github.com/Silent2012/moniq/issues)

</div>

---

![Dashboard](screenshots/dashboard.png)

---

## What is moniq?

moniq is a free, open-source macOS app that gives you a live view of everything your Mac is doing — CPU, memory, network, disk, battery, and per-app usage — without slowing it down. All system calls run off the main thread so moniq stays invisible until you need it.

Click the menu bar icon to open the popover. Pin any metric so it stays visible at a glance. That's it.

---

## Features

### Dashboard
A four-card hero row gives you the most important metrics at a glance — CPU usage with live sparkline, memory pressure (App / Wired / Compressed / Cached / Swap), network speeds, and battery. Scroll down for a full CPU performance chart with per-core breakdown and memory ring with detailed segment legend.

### CPU & Memory
- Real-time CPU usage with User / System / Idle split
- Per-core usage bars (reads directly from `host_processor_info`)
- Memory ring showing App, Wired, Compressed, Cached Files and Free — matches Activity Monitor exactly
- Swap usage with colour-coded progress bar
- Top processes table sortable by CPU or RAM

### Network & Disk
- Live download / upload speeds via `getifaddrs`
- Total session data transferred
- Disk read / write throughput with sparklines

### Battery

![Battery](screenshots/battery.png)

- Current charge %, time remaining, charging state
- Cycle count, design capacity, current capacity, voltage
- Battery health percentage with condition label
- 24-hour charge history chart

### App Usage
- Tracks which apps are open and for how long — updates live as you switch
- Per-app session history
- Today's total active time

### Analytics

![Analytics](screenshots/analytics.png)

- **7-Day Overview** — hourly-averaged CPU & memory as dual line chart, pinned to exact 7-day window so lines never overflow the boundary
- **Day History** — 5-minute bucketed CPU & memory for any recorded day, navigate with ← → arrows
- **Insights** — CPU peak, average CPU, memory pressure summary, data downloaded today

### Menu Bar
- Pin any combination of CPU, memory, battery, and network speed
- Coloured or plain-white icons to match your menu bar style
- Numbers animate smoothly with numeric transitions
- Popover opens on click with a compact live summary

---

## Installation

1. Download **moniq.dmg** from the [Releases](https://github.com/Silent2012/moniq/releases) page
2. Open the `.dmg` and drag **moniq.app** into Applications
3. Launch moniq — it will appear in your menu bar immediately

> **Requires macOS 13 Ventura or later · Apple Silicon (arm64)**

---

## Build from source

```bash
git clone https://github.com/Silent2012/moniq.git
cd moniq
bash build.sh
```

Requires the Command Line Tools SDK (`xcode-select --install`) and Python 3 (used to strip `#Preview` macros before `swiftc` compilation). No Xcode needed.

The compiled `.app` is installed to `~/Applications/moniq.app` automatically.

---

## Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Charts | Swift Charts |
| CPU / Memory | `host_processor_info`, `host_statistics64`, `sysctl` |
| Swap | `sysctlbyname("vm.swapusage")` |
| Processes | `proc_pidinfo` |
| Network | `getifaddrs` |
| Disk I/O | `sysctl` / `IOKit` |
| Battery | `IOKit` (IOPowerSources, IOService) |
| App tracking | `NSWorkspace` notifications |
| Analytics | Custom `AnalyticsRecorder` + `UserDefaults` persistence |
| Menu bar | `NSStatusItem` + `NSPopover` + `NSHostingView` |
| Threading | `Task.detached(priority: .utility)` — all kernel calls off main thread |

---

## Privacy

moniq reads system data locally using macOS APIs. It does not connect to the internet, collect telemetry, or send any data anywhere. Ever.

---

## License

MIT — free to use, modify, and distribute. See [LICENSE](LICENSE).

---

<div align="center">
  <sub>Built with SwiftUI · Free and open source · <a href="https://github.com/Silent2012/moniq">github.com/Silent2012/moniq</a></sub>
</div>
