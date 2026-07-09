import AppKit

final class TouchBarQuotaView: NSView {
    private let fiveHourLabel = NSTextField(labelWithString: "5h --%")
    private let fiveHourBar = QuotaBarView()
    private let weeklyLabel = NSTextField(labelWithString: "\(QuotaDisplayLabels.weeklyShort) --%")
    private let weeklyBar = QuotaBarView()
    private let fiveHourRefreshedAtLabel = NSTextField(labelWithString: "--:--")
    private let weeklyRefreshedAtLabel = NSTextField(labelWithString: "--:--")
    private let resetCreditsLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(with snapshot: QuotaSnapshot) {
        fiveHourLabel.stringValue = "5h \(Int(snapshot.fiveHourClampedPercent.rounded()))%"
        fiveHourBar.percent = snapshot.fiveHourClampedPercent
        weeklyLabel.stringValue = "\(QuotaDisplayLabels.weeklyShort) \(Int(snapshot.weeklyClampedPercent.rounded()))%"
        weeklyBar.percent = snapshot.weeklyClampedPercent
        fiveHourRefreshedAtLabel.stringValue = DateFormatters.touchBarDateTime.string(from: snapshot.fiveHourResetAt)
        weeklyRefreshedAtLabel.stringValue = DateFormatters.touchBarDateTime.string(from: snapshot.weeklyResetAt)
        resetCreditsLabel.stringValue = snapshot.resetCreditsDisplay ?? ""
        resetCreditsLabel.isHidden = snapshot.resetCreditsDisplay == nil
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 6

        [fiveHourLabel, weeklyLabel].forEach {
            $0.font = .systemFont(ofSize: 11, weight: .semibold)
            $0.textColor = .labelColor
            $0.alignment = .right
            $0.lineBreakMode = .byTruncatingTail
        }

        [fiveHourRefreshedAtLabel, weeklyRefreshedAtLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            $0.textColor = .secondaryLabelColor
            $0.alignment = .right
            $0.lineBreakMode = .byClipping
        }

        resetCreditsLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        resetCreditsLabel.textColor = .secondaryLabelColor
        resetCreditsLabel.alignment = .right
        resetCreditsLabel.lineBreakMode = .byClipping
        resetCreditsLabel.isHidden = true

        let fiveHourTextStack = NSStackView(views: [fiveHourLabel, fiveHourRefreshedAtLabel])
        fiveHourTextStack.orientation = .horizontal
        fiveHourTextStack.spacing = 6
        fiveHourTextStack.alignment = .centerY

        let weeklyTextStack = NSStackView(views: [weeklyLabel, weeklyRefreshedAtLabel, resetCreditsLabel])
        weeklyTextStack.orientation = .horizontal
        weeklyTextStack.spacing = 6
        weeklyTextStack.alignment = .centerY

        let fiveHourRow = NSStackView(views: [fiveHourBar, fiveHourTextStack])
        fiveHourRow.orientation = .horizontal
        fiveHourRow.spacing = 7
        fiveHourRow.alignment = .centerY

        let weeklyRow = NSStackView(views: [weeklyBar, weeklyTextStack])
        weeklyRow.orientation = .horizontal
        weeklyRow.spacing = 7
        weeklyRow.alignment = .centerY

        let stack = NSStackView(views: [fiveHourRow, weeklyRow])
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 252),
            heightAnchor.constraint(equalToConstant: 30),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            fiveHourBar.widthAnchor.constraint(equalToConstant: 102),
            weeklyBar.widthAnchor.constraint(equalToConstant: 102),
            fiveHourTextStack.widthAnchor.constraint(equalToConstant: 124),
            weeklyTextStack.widthAnchor.constraint(equalToConstant: 124),
            fiveHourBar.heightAnchor.constraint(equalToConstant: 5),
            weeklyBar.heightAnchor.constraint(equalToConstant: 5)
        ])
    }
}
