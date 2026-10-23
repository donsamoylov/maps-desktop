import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var controller: MapWindowController?
    private let themeMenu = NSMenu(title: L("Appearance"))

    /// Обычный запуск (из Dock, Finder, Spotlight) или ради ссылки. launchIsDefaultUserInfoKey для этого
    /// не годится: при восстановлении состояния macOS отдает false и на обычном запуске.
    private var plainLaunch = true

    func applicationWillFinishLaunching(_ note: Notification) {
        if let event = NSAppleEventManager.shared().currentAppleEvent {
            plainLaunch = event.eventID == kAEOpenApplication || event.eventID == kAEReopenApplication
        }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.mainMenu = buildMenu()
        if plainLaunch, controller == nil { show(MapsLink.home) }
        Updater.shared.start()
        ChromeExtension.launch()
    }

    /// Сюда приходят перехваченные ссылки: карты открываем, остальное отдаем браузеру.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let web = MapsLink.webURL(for: url) {
                show(web)
            } else if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                LinkRouter.openInBrowser(url)
            }
        }
        // Запущены только ради пересылки ссылки в браузер — окно не нужно, уходим.
        if controller == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { if self.controller == nil { NSApp.terminate(nil) } }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { show(nil) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func show(_ url: URL?) {
        if controller == nil {
            controller = MapWindowController()
            controller?.load(url ?? MapsLink.home)
        } else if let url {
            controller?.load(url)
        }
        controller?.showWindow(nil)
        NSApp.activate()
    }

    // MARK: Меню

    private func buildMenu() -> NSMenu {
        let main = NSMenu()

        let app = submenu(main, "Maps Desktop")
        app.addItem(withTitle: L("About Maps Desktop"),
                    action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(withTitle: L("Check for Updates…"), action: #selector(Updater.checkForUpdates(_:)),
                    keyEquivalent: "").target = Updater.shared
        app.addItem(.separator())
        app.addItem(withTitle: L("Install Chrome Extension…"), action: #selector(installExtension(_:)),
                    keyEquivalent: "").target = self
        app.addItem(.separator())
        app.addItem(withTitle: L("Hide Maps Desktop"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: L("Hide Others"),
                                 action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(.separator())
        app.addItem(withTitle: L("Quit Maps Desktop"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = submenu(main, L("File"))
        file.addItem(withTitle: L("Map Window"), action: #selector(newWindow(_:)), keyEquivalent: "n")
        file.addItem(withTitle: L("Search"), action: #selector(MapWindowController.focusSearch(_:)), keyEquivalent: "l")
        file.addItem(withTitle: L("Copy Link"), action: #selector(MapWindowController.copyLink(_:)), keyEquivalent: "C")
        file.addItem(withTitle: L("Open in Browser"), action: #selector(MapWindowController.openInBrowser(_:)), keyEquivalent: "O")
        file.addItem(.separator())
        file.addItem(withTitle: L("Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = submenu(main, L("Edit"))
        edit.addItem(withTitle: L("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: L("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Find"), action: #selector(MapWindowController.focusSearch(_:)), keyEquivalent: "f")

        let view = submenu(main, L("View"))
        view.addItem(withTitle: L("Reload"), action: #selector(MapWindowController.reload(_:)), keyEquivalent: "r")
        view.addItem(.separator())
        view.addItem(withTitle: L("Zoom In"), action: #selector(MapWindowController.zoomIn(_:)), keyEquivalent: "+")
        view.addItem(withTitle: L("Zoom Out"), action: #selector(MapWindowController.zoomOut(_:)), keyEquivalent: "-")
        view.addItem(withTitle: L("Actual Size"), action: #selector(MapWindowController.actualSize(_:)), keyEquivalent: "0")
        view.addItem(.separator())
        let full = view.addItem(withTitle: L("Enter Full Screen"), action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.command, .control]

        // Оформление: «Авто» — как в системе (по умолчанию), или всегда светлое / темное.
        main.addItem(withTitle: L("Appearance"), action: nil, keyEquivalent: "").submenu = themeMenu
        themeMenu.delegate = self

        let go = submenu(main, L("Go"))
        go.addItem(withTitle: L("Back"), action: #selector(MapWindowController.goBack(_:)), keyEquivalent: "[")
        go.addItem(withTitle: L("Forward"), action: #selector(MapWindowController.goForward(_:)), keyEquivalent: "]")
        go.addItem(withTitle: L("Home"), action: #selector(MapWindowController.goHome(_:)), keyEquivalent: "H")

        let window = submenu(main, L("Window"))
        window.addItem(withTitle: L("Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: L("Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = window
        return main
    }

    private func submenu(_ main: NSMenu, _ title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        main.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
        return menu
    }

    /// Меню «Оформление» собирается заново при каждом открытии — отмечен текущий выбор.
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === themeMenu { return fillThemeMenu(menu) }
    }

    private func fillThemeMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        for (theme, title) in [(Theme.system, L("Auto")), (.light, L("Light")), (.dark, L("Dark"))] {
            let item = menu.addItem(withTitle: title, action: #selector(chooseTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.rawValue
            item.state = Theme.current == theme ? .on : .off
        }
    }

    @objc private func chooseTheme(_ sender: NSMenuItem) {
        Theme.current = Theme(rawValue: sender.representedObject as? String ?? "") ?? .system
        controller?.applyTheme()
    }

    /// Ссылки на карты из Chrome передает приложению расширение «Open in Maps Desktop».
    @objc private func installExtension(_ sender: Any?) { ChromeExtension.install() }

    @objc private func newWindow(_ sender: Any?) { show(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
