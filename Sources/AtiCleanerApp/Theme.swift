import SwiftUI

enum Theme {
    static let accent = Color(red: 0.20, green: 0.50, blue: 0.98)
    static let navy = Color(red: 0.035, green: 0.085, blue: 0.18)
    static let junk = Color(red: 0.47, green: 0.52, blue: 0.60)
    static let large = Color.orange
    static let duplicates = Color.purple
    static let trash = Color.cyan
    static let uninstall = Color.red
    static let memory = Color.green
}

extension Int64 {
    var formattedBytes: String { ByteCountFormatter.string(fromByteCount: self, countStyle: .file) }
}
