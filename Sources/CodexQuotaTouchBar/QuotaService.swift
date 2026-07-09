import AppKit
import Foundation

extension Notification.Name {
    static let quotaSnapshotDidChange = Notification.Name("quotaSnapshotDidChange")
}

final class QuotaService {
    private(set) var snapshot: QuotaSnapshot = .loading
    private var timer: Timer?
    private let provider: QuotaProviding

    init(provider: QuotaProviding = CompositeQuotaProvider()) {
        self.provider = provider
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc func refresh() {
        do {
            snapshot = try provider.loadSnapshot()
            AppLogger.shared.info("Quota refreshed: \(snapshot.displayTitle)")
        } catch {
            snapshot = QuotaSnapshot(
                fiveHourRemainingPercent: 0,
                weeklyRemainingPercent: 0,
                planName: "Codex",
                resetAt: nil,
                fiveHourResetAt: Date(),
                weeklyResetAt: Date(),
                resetCreditsAvailableCount: nil,
                sourceName: provider.sourceDescription,
                note: error.localizedDescription,
                isFallback: true
            )
            AppLogger.shared.error("Quota refresh failed: \(error.localizedDescription)")
        }

        NotificationCenter.default.post(
            name: .quotaSnapshotDidChange,
            object: self,
            userInfo: ["snapshot": snapshot]
        )
    }

    func openDataSource() {
        provider.openSource()
    }
}

protocol QuotaProviding {
    var sourceDescription: String { get }
    func loadSnapshot() throws -> QuotaSnapshot
    func openSource()
}

enum QuotaProviderError: LocalizedError {
    case invalidFile(URL)
    case noCodexRateLimitFound(URL)

    var errorDescription: String? {
        switch self {
        case .invalidFile(let url):
            return "Cannot read quota file: \(url.path)"
        case .noCodexRateLimitFound(let url):
            return "Cannot find Codex rate limit data under: \(url.path)"
        }
    }
}

final class CompositeQuotaProvider: QuotaProviding {
    private let codexProvider: QuotaProviding
    private let fallbackProvider: QuotaProviding
    private let useFallback: Bool

    init(
        codexProvider: QuotaProviding = CodexRateLimitProvider(),
        fallbackProvider: QuotaProviding = LocalQuotaFileProvider(),
        useFallback: Bool = ProcessInfo.processInfo.environment["CODEX_QUOTA_USE_FALLBACK"] == "1"
    ) {
        self.codexProvider = codexProvider
        self.fallbackProvider = fallbackProvider
        self.useFallback = useFallback
    }

    var sourceDescription: String {
        if useFallback {
            return "\(codexProvider.sourceDescription), fallback: \(fallbackProvider.sourceDescription)"
        }
        return codexProvider.sourceDescription
    }

    func loadSnapshot() throws -> QuotaSnapshot {
        do {
            return try codexProvider.loadSnapshot()
        } catch {
            AppLogger.shared.error("Codex rate limit provider failed: \(error.localizedDescription)")
            guard useFallback else {
                throw error
            }
            return try fallbackProvider.loadSnapshot()
        }
    }

    func openSource() {
        codexProvider.openSource()
    }
}

final class CodexRateLimitProvider: QuotaProviding {
    private let fileManager: FileManager
    private let sessionsDirectoryURL: URL
    private let acceptedLimitIDs: Set<String>?

    init(
        fileManager: FileManager = .default,
        sessionsDirectoryURL: URL? = nil,
        acceptedLimitIDs: Set<String>? = CodexRateLimitProvider.defaultAcceptedLimitIDs()
    ) {
        self.fileManager = fileManager
        self.sessionsDirectoryURL = sessionsDirectoryURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        self.acceptedLimitIDs = acceptedLimitIDs
    }

    var sourceDescription: String {
        sessionsDirectoryURL.path
    }

    func loadSnapshot() throws -> QuotaSnapshot {
        guard let result = try latestRateLimitEvent() else {
            throw QuotaProviderError.noCodexRateLimitFound(sessionsDirectoryURL)
        }

        let primaryRemaining = max(0, min(100, 100 - result.primary.usedPercent))
        let secondaryRemaining = max(0, min(100, 100 - result.secondary.usedPercent))

        return QuotaSnapshot(
            fiveHourRemainingPercent: primaryRemaining,
            weeklyRemainingPercent: secondaryRemaining,
            planName: result.planType ?? "Codex",
            resetAt: nil,
            fiveHourResetAt: result.primary.resetsAt,
            weeklyResetAt: result.secondary.resetsAt,
            resetCreditsAvailableCount: nil,
            sourceName: "Codex rate_limits",
            note: "Updated \(DateFormatters.shortDateTime.string(from: result.observedAt))",
            isFallback: false
        )
    }

    func openSource() {
        NSWorkspace.shared.open(sessionsDirectoryURL)
    }

    private func latestRateLimitEvent() throws -> RateLimitEvent? {
        let files = try recentSessionFiles(limit: 80)
        var latest: RateLimitEvent?

        for file in files {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }

            for line in content.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
                guard let event = parseRateLimitEvent(line: String(line)) else { continue }

                if latest == nil || event.observedAt > latest!.observedAt {
                    latest = event
                }
                break
            }
        }

        return latest
    }

    private func recentSessionFiles(limit: Int) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: sessionsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        let files = enumerator.compactMap { item -> (url: URL, modifiedAt: Date)? in
            guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            return (url, values?.contentModificationDate ?? .distantPast)
        }

        return files
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(limit)
            .map(\.url)
    }

    private func parseRateLimitEvent(line: String) -> RateLimitEvent? {
        guard
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let timestamp = object["timestamp"] as? String,
            let observedAt = DateFormatters.parseISO8601(timestamp),
            let payload = object["payload"] as? [String: Any],
            let rateLimits = payload["rate_limits"] as? [String: Any],
            acceptsRateLimit(rateLimits),
            let primary = parseWindow(rateLimits["primary"]),
            let secondary = parseWindow(rateLimits["secondary"])
        else {
            return nil
        }

        return RateLimitEvent(
            observedAt: observedAt,
            primary: primary,
            secondary: secondary,
            planType: rateLimits["plan_type"] as? String
        )
    }

    private func acceptsRateLimit(_ rateLimits: [String: Any]) -> Bool {
        guard let acceptedLimitIDs else { return true }
        guard let limitID = rateLimits["limit_id"] as? String else { return false }
        return acceptedLimitIDs.contains(limitID)
    }

    private func parseWindow(_ rawValue: Any?) -> RateLimitWindow? {
        guard let object = rawValue as? [String: Any] else { return nil }

        guard
            let usedPercent = doubleValue(object["used_percent"]),
            let resetsAtSeconds = doubleValue(object["resets_at"])
        else {
            return nil
        }

        let windowMinutes = doubleValue(object["window_minutes"]) ?? 0

        return RateLimitWindow(
            usedPercent: usedPercent,
            windowMinutes: windowMinutes,
            resetsAt: Date(timeIntervalSince1970: resetsAtSeconds)
        )
    }

    private func doubleValue(_ rawValue: Any?) -> Double? {
        if let value = rawValue as? Double { return value }
        if let value = rawValue as? Int { return Double(value) }
        if let value = rawValue as? String { return Double(value) }
        return nil
    }

    static func defaultAcceptedLimitIDs(environment: [String: String] = ProcessInfo.processInfo.environment) -> Set<String>? {
        let rawValue = environment["CODEX_QUOTA_LIMIT_ID"] ?? "codex"
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.isEmpty == false, trimmed != "*", trimmed.lowercased() != "all" else {
            return nil
        }

        let ids = trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return Set(ids)
    }
}

private struct RateLimitEvent {
    let observedAt: Date
    let primary: RateLimitWindow
    let secondary: RateLimitWindow
    let planType: String?
}

private struct RateLimitWindow {
    let usedPercent: Double
    let windowMinutes: Double
    let resetsAt: Date
}

final class LocalQuotaFileProvider: QuotaProviding {
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var sourceDescription: String {
        quotaFileURL.path
    }

    func loadSnapshot() throws -> QuotaSnapshot {
        try ensureQuotaFileExists()

        do {
            let data = try Data(contentsOf: quotaFileURL)
            let payload = try decoder.decode(QuotaFilePayload.self, from: data)
            let snapshot = payload.snapshot()
            try upgradeQuotaFileIfNeeded(payload: payload, snapshot: snapshot)
            return snapshot
        } catch {
            throw QuotaProviderError.invalidFile(quotaFileURL)
        }
    }

    func openSource() {
        try? ensureQuotaFileExists()
        NSWorkspace.shared.open(quotaFileURL)
    }

    private var supportDirectoryURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("CodexQuotaTouchBar", isDirectory: true)
    }

    private var quotaFileURL: URL {
        supportDirectoryURL.appendingPathComponent("quota.json")
    }

    private func ensureQuotaFileExists() throws {
        if fileManager.fileExists(atPath: supportDirectoryURL.path) == false {
            try fileManager.createDirectory(at: supportDirectoryURL, withIntermediateDirectories: true)
        }

        guard fileManager.fileExists(atPath: quotaFileURL.path) == false else { return }

        let payload = QuotaFilePayload(
            fiveHourRemainingPercent: 73,
            five_hour_remaining_percent: nil,
            weeklyRemainingPercent: 91,
            weekly_remaining_percent: nil,
            remainingPercent: nil,
            remaining_percent: nil,
            planName: "Codex",
            plan_name: nil,
            resetAt: nil,
            reset_at: nil,
            fiveHourResetAt: DateFormatters.iso8601.string(from: Date()),
            five_hour_reset_at: nil,
            weeklyResetAt: DateFormatters.iso8601.string(from: Date()),
            weekly_reset_at: nil,
            fiveHourRefreshedAt: DateFormatters.iso8601.string(from: Date()),
            five_hour_refreshed_at: nil,
            weeklyRefreshedAt: DateFormatters.iso8601.string(from: Date()),
            weekly_refreshed_at: nil,
            refreshedAt: DateFormatters.iso8601.string(from: Date()),
            refreshed_at: nil,
            updatedAt: DateFormatters.iso8601.string(from: Date()),
            updated_at: nil,
            resetCreditsAvailableCount: 1,
            reset_credits_available_count: nil,
            remainingResetCredits: nil,
            remaining_reset_credits: nil,
            sourceName: "Local quota.json",
            source_name: nil,
            note: "Demo data. Replace quota percentages and refresh timestamps with real Codex values."
        )

        let data = try encoder.encode(payload)
        try data.write(to: quotaFileURL, options: .atomic)
        AppLogger.shared.info("Created default quota file at \(quotaFileURL.path)")
    }

    private func upgradeQuotaFileIfNeeded(payload: QuotaFilePayload, snapshot: QuotaSnapshot) throws {
        let hasFiveHour = payload.fiveHourRemainingPercent != nil || payload.five_hour_remaining_percent != nil
        let hasWeekly = payload.weeklyRemainingPercent != nil || payload.weekly_remaining_percent != nil
        let hasFiveHourResetTime = payload.fiveHourResetAt != nil || payload.five_hour_reset_at != nil || payload.fiveHourRefreshedAt != nil || payload.five_hour_refreshed_at != nil
        let hasWeeklyResetTime = payload.weeklyResetAt != nil || payload.weekly_reset_at != nil || payload.weeklyRefreshedAt != nil || payload.weekly_refreshed_at != nil

        guard hasFiveHour == false || hasWeekly == false || hasFiveHourResetTime == false || hasWeeklyResetTime == false else { return }

        let upgraded = QuotaFilePayload(
            fiveHourRemainingPercent: snapshot.fiveHourClampedPercent,
            five_hour_remaining_percent: nil,
            weeklyRemainingPercent: snapshot.weeklyClampedPercent,
            weekly_remaining_percent: nil,
            remainingPercent: nil,
            remaining_percent: nil,
            planName: payload.planName ?? payload.plan_name ?? snapshot.planName,
            plan_name: nil,
            resetAt: payload.resetAt ?? payload.reset_at,
            reset_at: nil,
            fiveHourResetAt: DateFormatters.iso8601.string(from: snapshot.fiveHourResetAt),
            five_hour_reset_at: nil,
            weeklyResetAt: DateFormatters.iso8601.string(from: snapshot.weeklyResetAt),
            weekly_reset_at: nil,
            fiveHourRefreshedAt: nil,
            five_hour_refreshed_at: nil,
            weeklyRefreshedAt: nil,
            weekly_refreshed_at: nil,
            refreshedAt: nil,
            refreshed_at: nil,
            updatedAt: nil,
            updated_at: nil,
            resetCreditsAvailableCount: snapshot.resetCreditsAvailableCount,
            reset_credits_available_count: nil,
            remainingResetCredits: nil,
            remaining_reset_credits: nil,
            sourceName: payload.sourceName ?? payload.source_name ?? snapshot.sourceName,
            source_name: nil,
            note: payload.note ?? "Quota file upgraded for five-hour and weekly quota display."
        )

        let data = try encoder.encode(upgraded)
        try data.write(to: quotaFileURL, options: .atomic)
        AppLogger.shared.info("Upgraded quota file at \(quotaFileURL.path)")
    }
}
