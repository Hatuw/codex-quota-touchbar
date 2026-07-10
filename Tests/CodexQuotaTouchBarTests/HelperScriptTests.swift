import Foundation
import XCTest

final class HelperScriptTests: XCTestCase {
    func testHelperSuppliesDesktopOriginatorToAppServer() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("CodexQuotaTouchBarHelperTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let fakeCodex = directory.appendingPathComponent("codex")
        try """
        #!/bin/sh
        if [ "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" != "Codex Desktop" ]; then
          printf '%s\\n' '{"id":2,"error":{"code":-32603,"message":"wrong originator"}}'
          exit 0
        fi
        while IFS= read -r line; do
          case "$line" in
            *'"id":2'*)
              printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":25,"resetsAt":1781104076},"secondary":{"usedPercent":60,"resetsAt":1781690876}},"rateLimitResetCredits":{"availableCount":1}}}'
              ;;
          esac
        done
        """.write(to: fakeCodex, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeCodex.path)

        let helper = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/codex_quota_touchbar.sh")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [helper.path, "compact"]
        process.environment = [
            "HOME": directory.path,
            "PATH": "/usr/bin:/bin",
            "CODEX_CLI_PATH": fakeCodex.path,
            "CODEX_QUOTA_APP_SERVER_ATTEMPTS": "1",
            "CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS": "5",
            "CODEX_QUOTA_CACHE_FILE": directory.appendingPathComponent("cache.json").path,
            "CODEX_QUOTA_LOCALE": "en_US",
            "CODEX_QUOTA_SOURCE": "app-server",
        ]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, text)
        XCTAssertTrue(text.contains("75%"), text)
        XCTAssertTrue(text.contains("40%"), text)
        XCTAssertFalse(text.contains("wrong originator"), text)
    }
}
