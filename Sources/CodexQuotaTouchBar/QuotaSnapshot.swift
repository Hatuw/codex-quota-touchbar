import Foundation

struct QuotaSnapshot: Equatable {
    let fiveHourRemainingPercent: Double
    let weeklyRemainingPercent: Double
    let planName: String
    let resetAt: Date?
    let fiveHourResetAt: Date
    let weeklyResetAt: Date
    let resetCreditsAvailableCount: Int?
    let sourceName: String
    let note: String?
    let isFallback: Bool

    var fiveHourClampedPercent: Double {
        min(100, max(0, fiveHourRemainingPercent))
    }

    var weeklyClampedPercent: Double {
        min(100, max(0, weeklyRemainingPercent))
    }

    var displayTitle: String {
        "\(QuotaDisplayLabels.fiveHourTitle) \(Int(fiveHourClampedPercent.rounded()))%  \(QuotaDisplayLabels.weeklyShort) \(Int(weeklyClampedPercent.rounded()))%\(resetCreditsSuffix)"
    }

    var displaySubtitle: String {
        "\(QuotaDisplayLabels.fiveHourResetTitle) \(DateFormatters.shortDateTime.string(from: fiveHourResetAt))  \(QuotaDisplayLabels.weeklyResetTitle) \(DateFormatters.shortDateTime.string(from: weeklyResetAt))"
    }

    var touchBarText: String {
        "5h \(Int(fiveHourClampedPercent.rounded()))% \(DateFormatters.touchBarDateTime.string(from: fiveHourResetAt))\n\(QuotaDisplayLabels.weeklyShort) \(Int(weeklyClampedPercent.rounded()))% \(DateFormatters.touchBarDateTime.string(from: weeklyResetAt))\(resetCreditsSuffix)"
    }

    var resetCreditsDisplay: String? {
        guard let resetCreditsAvailableCount else { return nil }
        return "🎟️×\(max(0, resetCreditsAvailableCount))"
    }

    private var resetCreditsSuffix: String {
        guard let resetCreditsDisplay else { return "" }
        return " \(resetCreditsDisplay)"
    }

    static let loading = QuotaSnapshot(
        fiveHourRemainingPercent: 0,
        weeklyRemainingPercent: 0,
        planName: "Codex",
        resetAt: nil,
        fiveHourResetAt: Date(),
        weeklyResetAt: Date(),
        resetCreditsAvailableCount: nil,
        sourceName: "Loading",
        note: "Loading quota data",
        isFallback: true
    )
}

enum QuotaDisplayLabels {
    static var fiveHourTitle: String {
        usesChineseLabels() ? "5小时" : "5h"
    }

    static var fiveHourQuotaTitle: String {
        usesChineseLabels() ? "5小时额度" : "5h quota"
    }

    static var weeklyShort: String {
        weeklyShortLabel()
    }

    static var weeklyQuotaTitle: String {
        usesChineseLabels() ? "周额度" : "Weekly quota"
    }

    static var fiveHourResetTitle: String {
        usesChineseLabels() ? "5小时刷新" : "5h reset"
    }

    static var weeklyResetTitle: String {
        usesChineseLabels() ? "周刷新" : "Weekly reset"
    }

    static func weeklyShortLabel(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        localeIdentifier: String = Locale.autoupdatingCurrent.identifier,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        if let override = environment["CODEX_QUOTA_WEEK_LABEL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           override.isEmpty == false {
            return override
        }

        return usesChineseLabels(
            environment: environment,
            localeIdentifier: localeIdentifier,
            preferredLanguages: preferredLanguages
        ) ? "周" : "W"
    }

    static func usesChineseLabels(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        localeIdentifier: String = Locale.autoupdatingCurrent.identifier,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Bool {
        let candidates: [String?] = [
            environment["CODEX_QUOTA_LOCALE"],
            localeIdentifier,
            preferredLanguages.first
        ]

        for candidate in candidates {
            guard let locale = firstLocale(candidate) else { continue }
            let normalized = locale.lowercased().replacingOccurrences(of: "-", with: "_")
            if normalized == "zh" || normalized.hasPrefix("zh_") || normalized.hasPrefix("zh.") {
                return true
            }
            return false
        }

        return false
    }

    private static func firstLocale(_ rawValue: String?) -> String? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }

        let separators = CharacterSet(charactersIn: ":,;()\"'").union(.whitespacesAndNewlines)
        return rawValue
            .components(separatedBy: separators)
            .first { candidate in
                candidate.range(of: #"^[A-Za-z]{2,3}([_-][A-Za-z0-9]+)*"#, options: .regularExpression) != nil
            }
    }
}

struct QuotaFilePayload: Codable {
    var fiveHourRemainingPercent: Double? = nil
    var five_hour_remaining_percent: Double? = nil
    var weeklyRemainingPercent: Double? = nil
    var weekly_remaining_percent: Double? = nil
    var remainingPercent: Double? = nil
    var remaining_percent: Double? = nil
    var planName: String? = nil
    var plan_name: String? = nil
    var resetAt: String? = nil
    var reset_at: String? = nil
    var fiveHourResetAt: String? = nil
    var five_hour_reset_at: String? = nil
    var weeklyResetAt: String? = nil
    var weekly_reset_at: String? = nil
    var fiveHourRefreshedAt: String? = nil
    var five_hour_refreshed_at: String? = nil
    var weeklyRefreshedAt: String? = nil
    var weekly_refreshed_at: String? = nil
    var refreshedAt: String? = nil
    var refreshed_at: String? = nil
    var updatedAt: String? = nil
    var updated_at: String? = nil
    var resetCreditsAvailableCount: Int? = nil
    var reset_credits_available_count: Int? = nil
    var remainingResetCredits: Int? = nil
    var remaining_reset_credits: Int? = nil
    var sourceName: String? = nil
    var source_name: String? = nil
    var note: String? = nil

    func snapshot(now: Date = Date()) -> QuotaSnapshot {
        let legacyPercent = remainingPercent ?? remaining_percent
        let fiveHourPercent = fiveHourRemainingPercent ?? five_hour_remaining_percent ?? legacyPercent ?? 0
        let weeklyPercent = weeklyRemainingPercent ?? weekly_remaining_percent ?? legacyPercent ?? 0
        let plan = planName ?? plan_name ?? "Codex"
        let reset = resetAt ?? reset_at
        let refreshed = refreshedAt ?? refreshed_at ?? updatedAt ?? updated_at
        let fiveHourReset = fiveHourResetAt ?? five_hour_reset_at ?? fiveHourRefreshedAt ?? five_hour_refreshed_at ?? refreshed
        let weeklyReset = weeklyResetAt ?? weekly_reset_at ?? weeklyRefreshedAt ?? weekly_refreshed_at ?? refreshed
        let resetCredits = resetCreditsAvailableCount ?? reset_credits_available_count ?? remainingResetCredits ?? remaining_reset_credits

        return QuotaSnapshot(
            fiveHourRemainingPercent: fiveHourPercent,
            weeklyRemainingPercent: weeklyPercent,
            planName: plan,
            resetAt: DateFormatters.parseISO8601(reset),
            fiveHourResetAt: DateFormatters.parseISO8601(fiveHourReset) ?? now,
            weeklyResetAt: DateFormatters.parseISO8601(weeklyReset) ?? now,
            resetCreditsAvailableCount: resetCredits.map { max(0, $0) },
            sourceName: sourceName ?? source_name ?? "quota.json",
            note: note,
            isFallback: false
        )
    }
}

enum DateFormatters {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601NoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let touchBarDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()

    static func parseISO8601(_ rawValue: String?) -> Date? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }
        return iso8601.date(from: rawValue) ?? iso8601NoFraction.date(from: rawValue)
    }
}
