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
        let page = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * page
        let inactive = UInt64(stats.inactive_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let used = active + inactive + wired + compressed
        return MemorySnapshot(total: total, used: min(used, total), free: total > used ? total - used : 0, compressed: compressed)
        #else
        return nil
        #endif
    }
}
