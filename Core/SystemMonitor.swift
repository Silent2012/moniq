import Foundation
import Combine
import AppKit
import Darwin.Mach
import Darwin

// MARK: - SystemMonitor
// CPU via host_processor_info (tick deltas per core)
// Memory via host_statistics64 (matches Activity Monitor breakdown)
// Processes via sysctl + proc_pidinfo (no task_for_pid needed)
//
// All heavy kernel work runs on a background thread via Task.detached;
// only @Published updates land on the main actor.

// ── proc_pidinfo bridge (libSystem — no entitlement needed for same-user procs)
private let PROC_PIDTASKINFO_FLAVOR: Int32 = 4

private struct ProcTaskInfo {
    var pti_virtual_size:       UInt64 = 0
    var pti_resident_size:      UInt64 = 0
    var pti_total_user:         UInt64 = 0
    var pti_total_system:       UInt64 = 0
    var pti_threads_user:       UInt64 = 0
    var pti_threads_system:     UInt64 = 0
    var pti_policy:             Int32  = 0
    var pti_faults:             Int32  = 0
    var pti_pageins:            Int32  = 0
    var pti_cow_faults:         Int32  = 0
    var pti_messages_sent:      Int32  = 0
    var pti_messages_received:  Int32  = 0
    var pti_syscalls_mach:      Int32  = 0
    var pti_syscalls_unix:      Int32  = 0
    var pti_csw:                Int32  = 0
    var pti_threadnum:          Int32  = 0
    var pti_numrunning:         Int32  = 0
    var pti_priority:           Int32  = 0
}

@_silgen_name("proc_pidinfo")
@discardableResult
private func _proc_pidinfo(
    _ pid: Int32, _ flavor: Int32, _ arg: UInt64,
    _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32
) -> Int32

private let FSCALE: Double = 2048.0

// ── Static host page size (arm64 = 16 384 B, x86_64 = 4 096 B)
private let kPageSize: UInt64 = {
    var p: vm_size_t = 0
    host_page_size(mach_host_self(), &p)
    return UInt64(p)
}()

private let kTotalRAM = ProcessInfo.processInfo.physicalMemory

// MARK: - SystemMonitor

@MainActor
final class SystemMonitor: ObservableObject {

    // MARK: - Published
    @Published var cpuData:    CPUData    = .zero
    @Published var memoryData: MemoryData = .zero
    @Published var processes:  [ProcessItem] = []

    @Published var cpuHistory: [Double] = Array(repeating: 0, count: AppConstants.History.sparklinePoints)
    @Published var memHistory: [Double] = Array(repeating: 0, count: AppConstants.History.sparklinePoints)

    @Published var isLoading = true
    @Published var error: String?

    // MARK: - Private
    private var timerCancellable: AnyCancellable?
    private var previousCPUInfo: [Int32] = []
    private var tickCount = 0
    // Process scan runs at most every 3 s regardless of base interval
    private let processTickInterval = 3

    // MARK: - Init
    init() { startMonitoring(interval: AppConstants.Interval.normal) }

    deinit { timerCancellable?.cancel() }

    // MARK: - Public
    func startMonitoring(interval: TimeInterval) {
        timerCancellable?.cancel()
        tickCount = 0
        timerCancellable = Timer
            .publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        tick()          // immediate first sample
        isLoading = false
    }

    func setInterval(_ interval: TimeInterval) {
        startMonitoring(interval: interval)
    }

    // MARK: - Tick (fires on main, dispatches work to background)
    private func tick() {
        tickCount += 1
        let shouldUpdateProcesses = tickCount % processTickInterval == 0 || tickCount == 1
        let prevCPU = previousCPUInfo   // capture immutable snapshot on main

        Task.detached(priority: .utility) { [weak self] in
            let (cpu, newPrev) = SystemMonitor.collectCPU(previous: prevCPU)
            let mem            = SystemMonitor.collectMemory()
            let procs: [ProcessItem]? = shouldUpdateProcesses
                ? SystemMonitor.collectProcesses()
                : nil

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.previousCPUInfo = newPrev
                self.cpuData = cpu
                self.memoryData = mem

                self.cpuHistory.append(cpu.usage)
                if self.cpuHistory.count > AppConstants.History.sparklinePoints {
                    self.cpuHistory.removeFirst()
                }
                self.memHistory.append(mem.usagePercent)
                if self.memHistory.count > AppConstants.History.sparklinePoints {
                    self.memHistory.removeFirst()
                }

                if let procs {
                    self.processes = procs
                }
            }
        }
    }

    // MARK: - CPU collection (background-safe, no self access)

    nonisolated static func collectCPU(previous: [Int32]) -> (data: CPUData, newPrev: [Int32]) {
        var numCPUs: natural_t = 0
        var cpuInfoPtr: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &numCPUs, &cpuInfoPtr, &numCPUInfo
        )
        guard result == KERN_SUCCESS, let cpuInfoPtr else {
            return (.zero, previous)
        }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: cpuInfoPtr),
                          vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let cpuCount  = Int(numCPUs)
        let infoCount = cpuCount * Int(CPU_STATE_MAX)
        var current   = [Int32](repeating: 0, count: infoCount)
        for i in 0..<infoCount { current[i] = cpuInfoPtr[i] }

        var coreUsages  = [Double]()
        var totalUser:   Double = 0
        var totalSystem: Double = 0
        var totalIdle:   Double = 0

        for core in 0..<cpuCount {
            let base = core * Int(CPU_STATE_MAX)
            let curUser   = current[base + Int(CPU_STATE_USER)]
            let curSystem = current[base + Int(CPU_STATE_SYSTEM)]
            let curIdle   = current[base + Int(CPU_STATE_IDLE)]
            let curNice   = current[base + Int(CPU_STATE_NICE)]

            let dUser:   Double
            let dSystem: Double
            let dIdle:   Double
            let dNice:   Double

            if previous.count == infoCount {
                dUser   = Double(curUser   - previous[base + Int(CPU_STATE_USER)])
                dSystem = Double(curSystem - previous[base + Int(CPU_STATE_SYSTEM)])
                dIdle   = Double(curIdle   - previous[base + Int(CPU_STATE_IDLE)])
                dNice   = Double(curNice   - previous[base + Int(CPU_STATE_NICE)])
            } else {
                dUser = Double(curUser); dSystem = Double(curSystem)
                dIdle = Double(curIdle); dNice   = Double(curNice)
            }

            let total = dUser + dSystem + dIdle + dNice
            if total > 0 {
                coreUsages.append(max(0, min(100, (dUser + dSystem + dNice) / total * 100)))
                totalUser   += dUser
                totalSystem += dSystem
                totalIdle   += dIdle
            } else {
                coreUsages.append(0)
            }
        }

        let grandTotal = totalUser + totalSystem + totalIdle
        let usage      = grandTotal > 0 ? (totalUser + totalSystem) / grandTotal * 100 : 0
        let userPct    = grandTotal > 0 ? totalUser   / grandTotal * 100 : 0
        let systemPct  = grandTotal > 0 ? totalSystem / grandTotal * 100 : 0
        let idlePct    = grandTotal > 0 ? totalIdle   / grandTotal * 100 : 100

        let data = CPUData(
            usage:         max(0, min(100, usage)),
            userPercent:   max(0, min(100, userPct)),
            systemPercent: max(0, min(100, systemPct)),
            idlePercent:   max(0, min(100, idlePct)),
            coreUsages:    coreUsages,
            timestamp:     Date()
        )
        return (data, current)
    }

    // MARK: - Memory collection (background-safe)

    nonisolated static func collectMemory() -> MemoryData {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return .zero }

        // ── Swap via vm.swapusage sysctl ──────────────────────────────────────
        var swapUsed:  UInt64 = 0
        var swapTotal: UInt64 = 0
        var swapInfo   = xsw_usage()
        var swapSize   = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapInfo, &swapSize, nil, 0) == 0 {
            swapUsed  = UInt64(swapInfo.xsu_used)
            swapTotal = UInt64(swapInfo.xsu_total)
        }

        let ps = kPageSize
        return MemoryData(
            appMemory:        UInt64(stats.internal_page_count)   * ps,
            wiredMemory:      UInt64(stats.wire_count)            * ps,
            compressedMemory: UInt64(stats.compressor_page_count) * ps,
            cachedFiles:      UInt64(stats.external_page_count)   * ps,
            freeMemory:       UInt64(stats.free_count)            * ps,
            totalMemory:      kTotalRAM,
            swapUsed:         swapUsed,
            swapTotal:        swapTotal
        )
    }

    // MARK: - Process collection (background-safe, throttled to every 3 s)

    nonisolated static func collectProcesses() -> [ProcessItem] {
        var mib  = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return [] }

        var buffer = [kinfo_proc](repeating: kinfo_proc(),
                                  count: size / MemoryLayout<kinfo_proc>.stride)
        guard sysctl(&mib, 4, &buffer, &size, nil, 0) == 0 else { return [] }

        // NSWorkspace is documented thread-safe
        let runningApps = NSWorkspace.shared.runningApplications
        var appByPID = [Int32: NSRunningApplication]()
        for a in runningApps { appByPID[a.processIdentifier] = a }

        var items = [ProcessItem]()

        for proc in buffer {
            let pid = proc.kp_proc.p_pid
            guard pid > 1 else { continue }

            let nameBytes = proc.kp_proc.p_comm
            let rawName = withUnsafeBytes(of: nameBytes) { ptr -> String in
                let chars = ptr.bindMemory(to: CChar.self)
                return String(cString: chars.baseAddress!)
            }
            guard !rawName.isEmpty else { continue }

            let app      = appByPID[pid]
            let dispName = app?.localizedName ?? rawName
            let bundleID = app?.bundleIdentifier
            let icon     = app?.icon

            let cpuPercent = Double(proc.kp_proc.p_pctcpu) / FSCALE * 100.0
            let memBytes   = getProcessMemory(pid: pid)

            let statusCode = Int32(proc.kp_proc.p_stat)
            let status: ProcessStatus
            switch statusCode {
            case 1, 2, 7: status = .running
            case 4:        status = .stopped
            case 5, 6:     status = .zombie
            default:       status = .sleeping
            }

            if memBytes > 0 || cpuPercent > 0 {
                items.append(ProcessItem(
                    id:          pid,
                    name:        dispName,
                    bundleID:    bundleID,
                    cpuPercent:  min(100, cpuPercent),
                    memoryBytes: memBytes,
                    status:      status,
                    icon:        icon
                ))
            }
        }

        return items
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(10)         // top 10 — down from 20
            .map { $0 }
    }

    nonisolated private static func getProcessMemory(pid: Int32) -> UInt64 {
        var info = ProcTaskInfo()
        let size = _proc_pidinfo(pid, PROC_PIDTASKINFO_FLAVOR, 0, &info,
                                 Int32(MemoryLayout<ProcTaskInfo>.size))
        return size > 0 ? info.pti_resident_size : 0
    }
}
