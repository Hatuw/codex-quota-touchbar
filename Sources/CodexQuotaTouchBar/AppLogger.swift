import Foundation

final class AppLogger {
    static let shared = AppLogger()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "CodexQuotaTouchBar.AppLogger")

    var logFileURL: URL {
        let base = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("CodexQuotaTouchBar", isDirectory: true)
            .appendingPathComponent("app.log")
    }

    func info(_ message: String) {
        write(level: "INFO", message: message)
    }

    func error(_ message: String) {
        write(level: "ERROR", message: message)
    }

    private func write(level: String, message: String) {
        queue.async { [logFileURL, fileManager] in
            let line = "\(DateFormatters.iso8601NoFraction.string(from: Date())) [\(level)] \(message)\n"
            let directory = logFileURL.deletingLastPathComponent()

            do {
                if fileManager.fileExists(atPath: directory.path) == false {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                }

                if fileManager.fileExists(atPath: logFileURL.path) == false {
                    try line.data(using: .utf8)?.write(to: logFileURL)
                    return
                }

                let handle = try FileHandle(forWritingTo: logFileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
            } catch {
                print("CodexQuotaTouchBar log failed: \(error.localizedDescription)")
            }
        }
    }
}
