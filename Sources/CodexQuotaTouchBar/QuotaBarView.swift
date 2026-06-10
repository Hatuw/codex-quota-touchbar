import AppKit

final class QuotaBarView: NSView {
    private let fillLayer = CALayer()

    var percent: Double = 0 {
        didSet {
            percent = min(100, max(0, percent))
            updateFill()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
        fillLayer.cornerRadius = bounds.height / 2
        updateFill()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.masksToBounds = true
        fillLayer.backgroundColor = NSColor.systemGreen.cgColor
        layer?.addSublayer(fillLayer)
    }

    private func updateFill() {
        guard bounds.width > 0 else { return }

        if percent <= 10 {
            fillLayer.backgroundColor = NSColor.systemRed.cgColor
        } else if percent <= 30 {
            fillLayer.backgroundColor = NSColor.systemOrange.cgColor
        } else {
            fillLayer.backgroundColor = NSColor.systemGreen.cgColor
        }

        let width = bounds.width * CGFloat(percent / 100)
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        fillLayer.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
        CATransaction.commit()
    }
}
