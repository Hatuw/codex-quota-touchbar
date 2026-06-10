import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let quotaService = QuotaService()
    private var windowController: QuotaWindowController?

    override init() {
        super.init()
        configureMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true

        windowController = QuotaWindowController(quotaService: quotaService)

        quotaService.start()
        showWindow()

        AppLogger.shared.info("CodexQuotaTouchBar launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLogger.shared.info("CodexQuotaTouchBar terminated")
    }

    @objc func showWindow() {
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(NSMenuItem(
            title: "自定义 Touch Bar",
            action: #selector(customizeTouchBar),
            keyEquivalent: ""
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "退出 CodexQuotaTouchBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }

    @objc private func customizeTouchBar() {
        showWindow()
        NSApp.toggleTouchBarCustomizationPalette(nil)
    }
}
