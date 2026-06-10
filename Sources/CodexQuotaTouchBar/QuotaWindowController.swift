import AppKit

final class QuotaWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class QuotaWindowController: NSWindowController {
    init(quotaService: QuotaService) {
        let controller = QuotaViewController(quotaService: quotaService)
        let window = QuotaWindow(contentViewController: controller)
        window.title = "Codex 剩余额度"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 420, height: 210))
        window.minSize = NSSize(width: 420, height: 210)
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
