import Foundation

public struct ScanProgress: Sendable {
    public var phase: String
    public var processed: Int64
    public var total: Int64
    public var detail: String?

    public init(phase: String, processed: Int64, total: Int64, detail: String? = nil) {
        self.phase = phase
        self.processed = processed
        self.total = total
        self.detail = detail
    }

    public var isDeterminate: Bool { total > 0 }
    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(processed) / Double(total), 0), 1)
    }
}

public struct CleanableItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let isDirectory: Bool
    public let date: Date?
    public var isSelected: Bool

    public init(id: String? = nil, name: String, path: String, size: Int64, isDirectory: Bool, date: Date? = nil, isSelected: Bool = true) {
        self.id = id ?? path
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.date = date
        self.isSelected = isSelected
    }
}

public enum JunkLocationKind: Hashable, Sendable {
    case directory
    case containerCaches
    case containerLogs
    case oldDownloads
    case derivedData
}

public struct JunkLocation: Hashable, Sendable {
    public let name: String
    public let path: String
    public let kind: JunkLocationKind

    public init(name: String, path: String, kind: JunkLocationKind = .directory) {
        self.name = name
        self.path = path
        self.kind = kind
    }
}

public struct JunkGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let iconName: String
    public let locations: [JunkLocation]
    public var items: [CleanableItem] = []
    public var isExpanded: Bool = true

    public init(id: String, name: String, iconName: String, locations: [JunkLocation]) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.locations = locations
    }

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    public var itemCount: Int { items.count }
    public var selectedSize: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    public var selectedCount: Int { items.filter(\.isSelected).count }

    public mutating func setAllSelected(_ selected: Bool) {
        for index in items.indices { items[index].isSelected = selected }
    }
}

public struct TrashResult: Sendable {
    public let succeeded: Int
    public let failed: Int
    public let freedBytes: Int64
    public let errors: [String]

    public init(succeeded: Int, failed: Int, freedBytes: Int64, errors: [String]) {
        self.succeeded = succeeded
        self.failed = failed
        self.freedBytes = freedBytes
        self.errors = errors
    }
}

public final class CancellationToken: @unchecked Sendable {
    private var _cancelled = false
    private let lock = NSLock()

    public init() {}

    public func cancel() {
        lock.lock()
        _cancelled = true
        lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cancelled
    }
}

public func formattedByteCount(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}