import Foundation
import XCTest

final class HelperScriptTests: XCTestCase {
    func testHelperSuppliesDesktopOriginatorToAppServer() throws {
        let output = try runHelper(
            rateLimitsJSON: """
            {"rateLimits":{"primary":{"usedPercent":25,"resetsAt":1781104076,"windowDurationMins":300},"secondary":{"usedPercent":60,"resetsAt":1781690876,"windowDurationMins":10080}},"rateLimitResetCredits":{"availableCount":1}}
            """
        )

        XCTAssertTrue(output.contains("75%"), output)
        XCTAssertTrue(output.contains("40%"), output)
        XCTAssertFalse(output.contains("wrong originator"), output)
    }

    func testHelperDisplaysSingleWeeklyWindow() throws {
        let output = try runHelper(
            rateLimitsJSON: """
            {"rateLimits":{"primary":{"usedPercent":2,"resetsAt":1784496077,"windowDurationMins":10080},"secondary":null},"rateLimitResetCredits":{"availableCount":1}}
            """
        )

        XCTAssertTrue(output.contains("W"), output)
        XCTAssertTrue(output.contains("98%"), output)
        XCTAssertTrue(output.contains("🎟️×1"), output)
        XCTAssertFalse(output.contains("5h"), output)
        XCTAssertFalse(output.contains("quota error"), output)
    }

    func testHelperReusesSingleWeeklyCacheAfterTransientFailure() throws {
        let output = try runHelper(
            rateLimitsJSON: "{}",
            initialCacheJSON: """
            {"fiveHourRemainingPercent":null,"fiveHourResetAt":null,"weeklyRemainingPercent":55,"weeklyResetAt":"2026-07-20T05:21:17+08:00","resetCreditsAvailableCount":1,"consecutiveFailures":0}
            """,
            forceError: true
        )

        XCTAssertTrue(output.contains("W"), output)
        XCTAssertTrue(output.contains("55%"), output)
        XCTAssertTrue(output.contains("🎟️×1"), output)
        XCTAssertFalse(output.contains("5h"), output)
        XCTAssertFalse(output.contains("quota error"), output)
    }

    private func runHelper(
        rateLimitsJSON: String,
        initialCacheJSON: String? = nil,
        forceError: Bool = false
    ) throws -> String {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("CodexQuotaTouchBarHelperTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let responseJSON = forceError
            ? "{\"id\":2,\"error\":{\"code\":-32603,\"message\":\"temporary failure\"}}"
            : "{\"id\":2,\"result\":\(rateLimitsJSON)}"
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
              printf '%s\\n' '\(responseJSON)'
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
        let cache = directory.appendingPathComponent("cache.json")
        if let initialCacheJSON {
            try initialCacheJSON.write(to: cache, atomically: true, encoding: .utf8)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [helper.path, "compact"]
        process.environment = [
            "HOME": directory.path,
            "PATH": "/usr/bin:/bin",
            "CODEX_CLI_PATH": fakeCodex.path,
            "CODEX_QUOTA_APP_SERVER_ATTEMPTS": "1",
            "CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS": "5",
            "CODEX_QUOTA_CACHE_FILE": cache.path,
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
        return text
    }
}
