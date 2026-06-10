import AppKit

final class QuotaSummaryView: NSView {
    private let titleLabel = NSTextField(labelWithString: "Codex --%")
    private let subtitleLabel = NSTextField(labelWithString: "Loading")
    private let fiveHourBar = QuotaBarView()
    private let weeklyBar = QuotaBarView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(with snapshot: QuotaSnapshot) {
        titleLabel.stringValue = snapshot.displayTitle
        subtitleLabel.stringValue = snapshot.note ?? snapshot.displaySubtitle
        fiveHourBar.percent = snapshot.fiveHourClampedPercent
        weeklyBar.percent = snapshot.weeklyClampedPercent
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let fiveHourLabel = NSTextField(labelWithString: QuotaDisplayLabels.fiveHourQuotaTitle)
        let weeklyLabel = NSTextField(labelWithString: QuotaDisplayLabels.weeklyQuotaTitle)
        [fiveHourLabel, weeklyLabel].forEach {
            $0.font = .systemFont(ofSize: 12, weight: .regular)
            $0.textColor = .secondaryLabelColor
        }

        let fiveHourStack = NSStackView(views: [fiveHourLabel, fiveHourBar])
        fiveHourStack.orientation = .vertical
        fiveHourStack.spacing = 4
        fiveHourStack.alignment = .leading

        let weeklyStack = NSStackView(views: [weeklyLabel, weeklyBar])
        weeklyStack.orientation = .vertical
        weeklyStack.spacing = 4
        weeklyStack.alignment = .leading

        let barsStack = NSStackView(views: [fiveHourStack, weeklyStack])
        barsStack.orientation = .horizontal
        barsStack.spacing = 16
        barsStack.alignment = .top

        let stack = NSStackView(views: [titleLabel, barsStack, subtitleLabel])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 260),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            fiveHourBar.widthAnchor.constraint(equalToConstant: 160),
            weeklyBar.widthAnchor.constraint(equalToConstant: 160),
            fiveHourBar.heightAnchor.constraint(equalToConstant: 8),
            weeklyBar.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
}
