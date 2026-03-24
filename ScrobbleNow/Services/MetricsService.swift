import Foundation
import AppKit

@MainActor
class MetricsService: ObservableObject {
    static let shared = MetricsService()

    // Memory
    @Published var realMemoryMB: Double = 0
    @Published var privateMemoryMB: Double = 0
    @Published var virtualMemoryGB: Double = 0
    @Published var sharedMemoryMB: Double = 0

    // CPU
    @Published var cpuUsagePercent: Double = 0
    @Published var cpuTimeSec: Double = 0

    // Threads & Ports
    @Published var threadCount: Int = 0
    @Published var portCount: Int = 0

    // Faults & Syscalls
    @Published var contextSwitches: Int64 = 0
    @Published var pageFaults: Int64 = 0
    @Published var pageIns: Int64 = 0
    @Published var machSysCalls: Int64 = 0
    @Published var unixSysCalls: Int64 = 0

    // App
    @Published var uptime: TimeInterval = 0
    @Published var heapAllocMB: Double = 0

    // History
    @Published var memoryHistory: [Double] = []
    @Published var cpuHistory: [Double] = []

    private let startTime = Date()
    private var timer: Timer?
    private let maxHistory = 60

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sample() }
        }
        sample()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        uptime = Date().timeIntervalSince(startTime)
        sampleMemory()
        cpuUsagePercent = sampleCPU()
        heapAllocMB = sampleHeap()
        threadCount = sampleThreadCount()
        sampleTaskEvents()

        memoryHistory.append(realMemoryMB)
        cpuHistory.append(cpuUsagePercent)
        if memoryHistory.count > maxHistory { memoryHistory.removeFirst() }
        if cpuHistory.count > maxHistory { cpuHistory.removeFirst() }
    }

    // MARK: - Memory (task_vm_info — matches Activity Monitor)

    private func sampleMemory() {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        realMemoryMB = Double(info.phys_footprint) / 1_048_576.0
        let internalMem = Double(info.internal) / 1_048_576.0
        let reusable = Double(info.reusable) / 1_048_576.0
        privateMemoryMB = internalMem - reusable
        virtualMemoryGB = Double(info.virtual_size) / 1_073_741_824.0

        // Shared = resident - private (approximate)
        var basicInfo = mach_task_basic_info()
        var basicCount = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let basicResult = withUnsafeMutablePointer(to: &basicInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(basicCount)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &basicCount)
            }
        }
        if basicResult == KERN_SUCCESS {
            let residentMB = Double(basicInfo.resident_size) / 1_048_576.0
            sharedMemoryMB = max(0, residentMB - privateMemoryMB)
        }
    }

    // MARK: - CPU

    private func sampleCPU() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else { return 0 }

        var totalCPU: Double = 0
        var totalTimeSec: Double = 0

        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            if kr == KERN_SUCCESS {
                if info.flags & TH_FLAGS_IDLE == 0 {
                    totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
                totalTimeSec += Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000.0
                totalTimeSec += Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000.0
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size))
        cpuTimeSec = totalTimeSec
        return totalCPU
    }

    // MARK: - Task Events (context switches, faults, syscalls)

    private func sampleTaskEvents() {
        var events = task_events_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_events_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &events) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_EVENTS_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        contextSwitches = Int64(events.csw)
        pageFaults = Int64(events.faults)
        pageIns = Int64(events.pageins)
        machSysCalls = Int64(events.syscalls_mach)
        unixSysCalls = Int64(events.syscalls_unix)

        // Ports from Mach port space
        var portNames: mach_port_name_array_t?
        var portTypes: mach_port_type_array_t?
        var portNameCount: mach_msg_type_number_t = 0
        var portTypeCount: mach_msg_type_number_t = 0
        let pr = mach_port_names(mach_task_self_, &portNames, &portNameCount, &portTypes, &portTypeCount)
        if pr == KERN_SUCCESS {
            portCount = Int(portNameCount)
            if let names = portNames {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: names), vm_size_t(portNameCount) * vm_size_t(MemoryLayout<mach_port_name_t>.size))
            }
            if let types = portTypes {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: types), vm_size_t(portTypeCount) * vm_size_t(MemoryLayout<mach_port_type_t>.size))
            }
        }
    }

    private func sampleHeap() -> Double {
        var stats = malloc_statistics_t()
        malloc_zone_statistics(nil, &stats)
        return Double(stats.size_in_use) / 1_048_576.0
    }

    private func sampleThreadCount() -> Int {
        var threadList: thread_act_array_t?
        var count: mach_msg_type_number_t = 0
        let result = task_threads(mach_task_self_, &threadList, &count)
        if result == KERN_SUCCESS, let threads = threadList {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(count) * vm_size_t(MemoryLayout<thread_t>.size))
        }
        return Int(count)
    }

    // MARK: - Formatted

    var uptimeFormatted: String {
        let h = Int(uptime) / 3600
        let m = (Int(uptime) % 3600) / 60
        let s = Int(uptime) % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m \(s)s"
    }

    var cpuTimeFormatted: String {
        String(format: "%.2fs", cpuTimeSec)
    }
}
