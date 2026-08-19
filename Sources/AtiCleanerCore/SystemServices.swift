import Foundation
#if os(macOS)
import Darwin
#endif

public enum DiskService {
    public static func snapshot(at url: URL = FileManager.default.homeDirectoryForCurrentUser) -> DiskSnapshot? {
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]) else { return nil }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        return DiskSnapshot(total: total, available: available)
    }
}

public enum MemoryService {
    public static func snapshot() -> MemorySnapshot? {
        #if os(macOS)
        var size = MemoryLayout<UInt64>.size
        var total: UInt64 = 0
        sysctlbyname("hw.memsize", &total, &size, nil, 0)
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: stats) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }
        let page = UInt64(pageSize)
        let active = UInt64(stats.active_count) * page
        let inactive = UInt64(stats.inactive_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let cache = UInt64(stats.external_page_count) * page
        let used = active + inactive + wired + compressed
        return MemorySnapshot(total: total, used: min(used, total), free: total > used ? total - used : 0, compressed: compressed, cache: cache)
        #else
        return nil
        #endif
    }

    public static func freeUpMemory() -> MemoryReliefResult {
        #if os(macOS)
        let before = snapshot()?.used ?? 0
        var freed: UInt64 = 0
        if let zone = malloc_default_zone() {
            freed += UInt64(malloc_zone_pressure_relief(zone, 0))
        }
        var purgeSucceeded = false
        if !PrivilegedHelper.isInstalled() {
            let source = Bundle.main.executablePath ?? CommandLine.arguments[0]
            if PrivilegedHelper.install(sourceBinary: source) {
                if let token = PrivilegedHelper.trigger() {
                    purgeSucceeded = PrivilegedHelper.waitForCompletion(token: token)
                }
            }
        } else if let token = PrivilegedHelper.trigger() {
            purgeSucceeded = PrivilegedHelper.waitForCompletion(token: token)
        }
        let after = snapshot()?.used ?? 0
        return MemoryReliefResult(freed: freed, usedBefore: before, usedAfter: after, purgeSucceeded: purgeSucceeded)
        #else
        return MemoryReliefResult(freed: 0, usedBefore: 0, usedAfter: 0, purgeSucceeded: false)
        #endif
    }

    public static func runPurge() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
