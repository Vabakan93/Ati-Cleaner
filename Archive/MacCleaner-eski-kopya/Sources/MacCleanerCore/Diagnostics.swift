import Foundation

public enum Diagnostics {

    private static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AtiCleaner.log")
    }

    public static func log(_ message: String) {
        let line = "\(Date()): \(message)\n"
        let url = logURL
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } else {
                try line.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            // sessiz — log yazılamıyorsa sorun değil
        }
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: logURL)
    }
}