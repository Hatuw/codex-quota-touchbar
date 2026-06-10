import AppKit

final class QuotaViewController: NSViewController, NSTouchBarDelegate {
    private let quotaService: QuotaService
    private let summaryView = QuotaSummaryView()
    private var touchBarQuotaView: TouchBarQuotaView?

    init(quotaService: QuotaService) {
        self.quotaService = quotaService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let openFileButton = NSButton(
            title: "打开数据源",
            target: self,
            action: #selector(openDataSource)
        )
        openFileButton.bezelStyle = .rounded

        let refreshButton = NSButton(
            title: "刷新",
            target: self,
            action: #selector(refresh)
        )
        refreshButton.bezelStyle = .rounded

        let customizeButton = NSButton(
            title: "自定义 Touch Bar",
            target: self,
            action: #selector(customizeTouchBar)
        )
        customizeButton.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [openFileButton, refreshButton, customizeButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8

        let stack = NSStackView(views: [summaryView, buttonStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(greaterThanOrEqualToConstant: 360),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 170),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        summaryView.update(with: quotaService.snapshot)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSnapshotChange(_:)),
            name: .quotaSnapshotDidChange,
            object: quotaService
        )
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }

    override func makeTouchBar() -> NSTouchBar? {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.customizationIdentifier = .codexQuotaBar
        bar.defaultItemIdentifiers = [.codexQuota, .fixedSpaceSmall, .codexRefresh, .codexOpenDataSource]
        bar.customizationAllowedItemIdentifiers = [
            .codexQuota,
            .codexRefresh,
            .codexOpenDataSource,
            .fixedSpaceSmall,
            .fixedSpaceLarge,
            .flexibleSpace
        ]
        bar.customizationRequiredItemIdentifiers = [.codexQuota]
        return bar
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        if identifier == .codexRefresh {
            return makeButtonItem(identifier: identifier, title: "刷新", action: #selector(refresh))
        }

        if identifier == .codexOpenDataSource {
            return makeButtonItem(identifier: identifier, title: "数据源", action: #selector(openDataSource))
        }

        guard identifier == .codexQuota else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)
        let quotaView = TouchBarQuotaView()
        quotaView.update(with: quotaService.snapshot)
        item.view = quotaView
        item.customizationLabel = "Codex Quota"
        touchBarQuotaView = quotaView
        return item
    }

    private func makeButtonItem(
        identifier: NSTouchBarItem.Identifier,
        title: String,
        action: Selector
    ) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        item.view = button
        item.customizationLabel = title
        return item
    }

    @objc private func handleSnapshotChange(_ notification: Notification) {
        guard let snapshot = notification.userInfo?["snapshot"] as? QuotaSnapshot else { return }
        summaryView.update(with: snapshot)
        touchBarQuotaView?.update(with: snapshot)
    }

    @objc private func refresh() {
        quotaService.refresh()
    }

    @objc private func openDataSource() {
        quotaService.openDataSource()
    }

    @objc private func customizeTouchBar() {
        view.window?.makeKeyAndOrderFront(nil)
        view.window?.makeFirstResponder(view)
        NSApp.toggleTouchBarCustomizationPalette(nil)
    }
}

extension NSTouchBar.CustomizationIdentifier {
    static let codexQuotaBar = NSTouchBar.CustomizationIdentifier("io.github.codex-quota-touchbar.touchbar")
}

extension NSTouchBarItem.Identifier {
    static let codexQuota = NSTouchBarItem.Identifier("io.github.codex-quota-touchbar.quota")
    static let codexRefresh = NSTouchBarItem.Identifier("io.github.codex-quota-touchbar.refresh")
    static let codexOpenDataSource = NSTouchBarItem.Identifier("io.github.codex-quota-touchbar.openDataSource")
}
