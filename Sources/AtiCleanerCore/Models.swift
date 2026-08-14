import Foundation

public struct DiskSnapshot: Sendable {
    public let total: Int64
    public let available: Int64
    public var used: Int64 { max(total - available, 0) }
    public var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

public struct MemorySnapshot: Sendable {
    public let total: UInt64
    public let used: UInt64
    public let free: UInt64
    public let compressed: UInt64
}

public struct ScanProgress: Sendable {
    public let phase: String
    public let processed: Int64
    public let total: Int64
    public let detail: String?
    public init(phase: String, processed: Int64 = 0, total: Int64 = -1, detail: String? = nil) {
        self.phase = phase; self.processed = processed; self.total = total; self.detail = detail
    }
    public var isDeterminate: Bool { total > 0 }
    public var fraction: Double { total > 0 ? min(max(Double(processed) / Double(total), 0), 1) : 0 }
}

public struct CleanableItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let isDirectory: Bool
    public let date: Date?
    public var isSelected: Bool
    public init(name: String, path: String, size: Int64, isDirectory: Bool, date: Date? = nil, isSelected: Bool = true) {
        self.id = path; self.name = name; self.path = path; self.size = size; self.isDirectory = isDirectory; self.date = date; self.isSelected = isSelected
    }
}

public struct LargeFileResult: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let size: Int64
    public let date: Date?
    public var isSelected: Bool
    public init(path: String, size: Int64, date: Date?, isSelected: Bool = false) {
        self.id = path; self.name = URL(fileURLWithPath: path).lastPathComponent; self.path = path; self.size = size; self.date = date; self.isSelected = isSelected
    }
}

public struct DuplicateFile: Identifiable, Sendable, Hashable {
    public let id: String
    public let path: String
    public let size: Int64
    public let date: Date?
    public var isSelected: Bool
    public init(path: String, size: Int64, date: Date?, isSelected: Bool = false) {
        self.id = path; self.path = path; self.size = size; self.date = date; self.isSelected = isSelected
    }
}

public struct DuplicateGroup: Identifiable, Sendable, Hashable {
    public let id: String
    public let hash: String
    public let fileSize: Int64
    public var files: [DuplicateFile]
    public var isExpanded: Bool = true
    public init(hash: String, fileSize: Int64, files: [DuplicateFile]) {
        self.id = hash; self.hash = hash; self.fileSize = fileSize; self.files = files
    }
    public var selectedSize: Int64 { files.filter(\.isSelected).reduce(0) { $0 + $1.size } }
    public var selectedCount: Int { files.filter(\.isSelected).count }
    public var wasteSize: Int64 { Int64(max(files.count - 1, 0)) * fileSize }
}

public struct InstalledApp: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let bundleIdentifier: String?
    public let size: Int64
    public init(name: String, path: String, bundleIdentifier: String?, size: Int64) {
        self.id = path; self.name = name; self.path = path; self.bundleIdentifier = bundleIdentifier; self.size = size
    }
}
