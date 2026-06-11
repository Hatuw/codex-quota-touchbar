import XCTest
@testable import CodexQuotaTouchBar

final class QuotaSnapshotTests: XCTestCase {
    func testPayloadAcceptsCamelCaseFields() {
        let payload = QuotaFilePayload(
            fiveHourRemainingPercent: 42.4,
            weeklyRemainingPercent: 88.2,
            planName: "Codex Plus",
            resetAt: "2026-06-11T00:00:00+08:00",
            fiveHourResetAt: "2026-06-10T10:00:00+08:00",
            weeklyResetAt: "2026-06-10T11:00:00+08:00",
            refreshedAt: "2026-06-10T10:00:00+08:00",
            sourceName: "Unit Test",
            note: nil
        )

        let snapshot = payload.snapshot()

        XCTAssertEqual(snapshot.fiveHourClampedPercent, 42.4)
        XCTAssertEqual(snapshot.weeklyClampedPercent, 88.2)
        XCTAssertEqual(snapshot.planName, "Codex Plus")
        XCTAssertEqual(snapshot.sourceName, "Unit Test")
        XCTAssertNotNil(snapshot.resetAt)
        XCTAssertEqual(DateFormatters.shortTime.string(from: snapshot.fiveHourResetAt), "10:00")
        XCTAssertEqual(DateFormatters.shortTime.string(from: snapshot.weeklyResetAt), "11:00")
    }

    func testPercentIsClampedForDisplay() {
        let snapshot = QuotaSnapshot(
            fiveHourRemainingPercent: 133,
            weeklyRemainingPercent: -5,
            planName: "Codex",
            resetAt: nil,
            fiveHourResetAt: Date(),
            weeklyResetAt: Date(),
            sourceName: "Unit Test",
            note: nil,
            isFallback: false
        )

        XCTAssertEqual(snapshot.fiveHourClampedPercent, 100)
        XCTAssertEqual(snapshot.weeklyClampedPercent, 0)
        XCTAssertTrue(snapshot.displayTitle.contains("\(QuotaDisplayLabels.fiveHourTitle) 100%"))
        XCTAssertTrue(snapshot.displayTitle.contains("\(QuotaDisplayLabels.weeklyShort) 0%"))
    }

    func testWeeklyLabelFollowsLocale() {
        XCTAssertEqual(
            QuotaDisplayLabels.weeklyShortLabel(
                environment: [:],
                localeIdentifier: "zh_CN",
                preferredLanguages: []
            ),
            "周"
        )
        XCTAssertEqual(
            QuotaDisplayLabels.weeklyShortLabel(
                environment: [:],
                localeIdentifier: "en_US",
                preferredLanguages: []
            ),
            "W"
        )
        XCTAssertEqual(
            QuotaDisplayLabels.weeklyShortLabel(
                environment: ["CODEX_QUOTA_LOCALE": "zh-Hans-CN"],
                localeIdentifier: "en_US",
                preferredLanguages: []
            ),
            "周"
        )
        XCTAssertEqual(
            QuotaDisplayLabels.weeklyShortLabel(
                environment: ["CODEX_QUOTA_WEEK_LABEL": "Week"],
                localeIdentifier: "zh_CN",
                preferredLanguages: []
            ),
            "Week"
        )
    }

    func testLegacyPercentFeedsBothQuotaWindows() {
        let payload = QuotaFilePayload(
            remainingPercent: 64,
            updatedAt: "2026-06-10T10:00:00+08:00"
        )

        let snapshot = payload.snapshot()

        XCTAssertEqual(snapshot.fiveHourClampedPercent, 64)
        XCTAssertEqual(snapshot.weeklyClampedPercent, 64)
        XCTAssertEqual(DateFormatters.shortTime.string(from: snapshot.fiveHourResetAt), "10:00")
        XCTAssertEqual(DateFormatters.shortTime.string(from: snapshot.weeklyResetAt), "10:00")
    }

    func testCodexRateLimitProviderIgnoresOtherLimitIDs() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("CodexQuotaTouchBarTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        try writeJSONL(
            """
            {"timestamp":"2026-06-10T10:08:01.819Z","type":"event_msg","payload":{"rate_limits":{"limit_id":"codex_bengalfox","primary":{"used_percent":0.0,"window_minutes":300,"resets_at":1781104076},"secondary":{"used_percent":0.0,"window_minutes":10080,"resets_at":1781690876},"plan_type":null}}}
            """,
            to: directory.appendingPathComponent("newer-non-codex.jsonl")
        )
        try writeJSONL(
            """
            {"timestamp":"2026-06-10T10:07:43.170Z","type":"event_msg","payload":{"rate_limits":{"limit_id":"codex","primary":{"used_percent":36.0,"window_minutes":300,"resets_at":1781073401},"secondary":{"used_percent":80.0,"window_minutes":10080,"resets_at":1781139747},"plan_type":"pro"}}}
            """,
            to: directory.appendingPathComponent("older-codex.jsonl")
        )

        let provider = CodexRateLimitProvider(
            fileManager: fileManager,
            sessionsDirectoryURL: directory,
            acceptedLimitIDs: ["codex"]
        )

        let snapshot = try provider.loadSnapshot()

        XCTAssertEqual(snapshot.fiveHourClampedPercent, 64)
        XCTAssertEqual(snapshot.weeklyClampedPercent, 20)
        XCTAssertEqual(snapshot.planName, "pro")
    }

    func testCodexRateLimitProviderCanAcceptAllLimitIDs() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("CodexQuotaTouchBarTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        try writeJSONL(
            """
            {"timestamp":"2026-06-10T10:08:01.819Z","type":"event_msg","payload":{"rate_limits":{"limit_id":"codex_bengalfox","primary":{"used_percent":0.0,"window_minutes":300,"resets_at":1781104076},"secondary":{"used_percent":0.0,"window_minutes":10080,"resets_at":1781690876},"plan_type":null}}}
            """,
            to: directory.appendingPathComponent("newer-non-codex.jsonl")
        )
        try writeJSONL(
            """
            {"timestamp":"2026-06-10T10:07:43.170Z","type":"event_msg","payload":{"rate_limits":{"limit_id":"codex","primary":{"used_percent":36.0,"window_minutes":300,"resets_at":1781073401},"secondary":{"used_percent":80.0,"window_minutes":10080,"resets_at":1781139747},"plan_type":"pro"}}}
            """,
            to: directory.appendingPathComponent("older-codex.jsonl")
        )

        let provider = CodexRateLimitProvider(
            fileManager: fileManager,
            sessionsDirectoryURL: directory,
            acceptedLimitIDs: nil
        )

        let snapshot = try provider.loadSnapshot()

        XCTAssertEqual(snapshot.fiveHourClampedPercent, 100)
        XCTAssertEqual(snapshot.weeklyClampedPercent, 100)
    }

    func testCompositeProviderDoesNotUseFallbackByDefault() {
        let provider = CompositeQuotaProvider(
            codexProvider: FailingQuotaProvider(),
            fallbackProvider: StaticQuotaProvider(),
            useFallback: false
        )

        XCTAssertThrowsError(try provider.loadSnapshot())
    }

    func testCompositeProviderUsesFallbackWhenEnabled() throws {
        let provider = CompositeQuotaProvider(
            codexProvider: FailingQuotaProvider(),
            fallbackProvider: StaticQuotaProvider(),
            useFallback: true
        )

        let snapshot = try provider.loadSnapshot()

        XCTAssertEqual(snapshot.fiveHourClampedPercent, 12)
        XCTAssertEqual(snapshot.weeklyClampedPercent, 34)
        XCTAssertEqual(snapshot.sourceName, "Fallback Test")
    }

    private func writeJSONL(_ content: String, to url: URL) throws {
        try content.appending("\n").write(to: url, atomically: true, encoding: .utf8)
    }
}

private struct FailingQuotaProvider: QuotaProviding {
    var sourceDescription: String { "Failing Test" }

    func loadSnapshot() throws -> QuotaSnapshot {
        throw QuotaProviderError.noCodexRateLimitFound(URL(fileURLWithPath: "/tmp/missing"))
    }

    func openSource() {}
}

private struct StaticQuotaProvider: QuotaProviding {
    var sourceDescription: String { "Fallback Test" }

    func loadSnapshot() throws -> QuotaSnapshot {
        QuotaSnapshot(
            fiveHourRemainingPercent: 12,
            weeklyRemainingPercent: 34,
            planName: "Codex",
            resetAt: nil,
            fiveHourResetAt: Date(),
            weeklyResetAt: Date(),
            sourceName: sourceDescription,
            note: nil,
            isFallback: true
        )
    }

    func openSource() {}
}
