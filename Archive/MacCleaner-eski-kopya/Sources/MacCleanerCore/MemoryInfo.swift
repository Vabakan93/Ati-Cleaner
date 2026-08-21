import Foundation
import Darwin

public struct MemoryStatus {
    public let free: UInt64
    public let active: UInt64
    public let inactive: UInt64
    public let wired: UInt64
    public let compressed: UInt64
    public let total: UInt64

    public var used: UInt64 {
        let sum = active + wired + compressed
        return min(sum, total)
    }

    public var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    public var pressureLevel: String {
        let freeRatio = Double(total - used) / Double(total)
        if freeRatio < 0.10 { return "Kritik — kapatılabilir uygulamalar olabilir" }
        if freeRatio < 0.20 { return "Yüksek" }
        if freeRatio < 0.35 { return "Orta" }
        return "Düşük — bellek sağlıklı"
    }
}

public enum MemoryInfo {

    public static func currentStatus() -> MemoryStatus? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)

        return MemoryStatus(
            free: UInt64(stats.free_count) * pageSize,
            active: UInt64(stats.active_count) * pageSize,
            inactive: UInt64(stats.inactive_count) * pageSize,
            wired: UInt64(stats.wire_count) * pageSize,
            compressed: UInt64(stats.compressor_page_count) * pageSize,
            total: total
        )
    }

    @discardableResult
    public static func runPurge() -> String? {
        let script = "do shell script \"/usr/sbin/purge\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()

        let data = error.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (message?.isEmpty ?? true) ? nil : message
    }
}