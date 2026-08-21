import Foundation

public struct DiskStatus {
    public let total: Int64
    public let available: Int64

    public var used: Int64 { total - available }
    public var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }
}

public enum DiskUsage {

    public static func currentStatus() -> DiskStatus? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]) else { return nil }

        guard let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage
        else { return nil }

        return DiskStatus(
            total: Int64(total),
            available: Int64(available)
        )
    }
}