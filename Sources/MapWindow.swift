import AppKit
import WebKit

final class MapWindowController: NSWindowController, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate, NSMenuItemValidation {
    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()        // вход в аккаунт и настройки сохраняются
        config.preferences.isElementFullscreenEnabled = true
        config.userContentController.addScriptMessageHandler(LocationBridge(), contentWorld: .page,
                                                             name: LocationBridge.name)
        config.userContentController.addUserScript(LocationBridge.userScript)
        webView = MapWebView(frame: .zero, configuration: config)
        // Представляемся сайту как Chrome: Safari Google отдает карту, в которой при быстром сдвиге
        // разом моргают все подписи.
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
        webView.allowsBackForwardNavigationGestures = false   // иначе горизонтальный свайп по трекпаду уходит в «назад» вместо сдвига карты
        webView.allowsMagnification = false                // щипок должен масштабировать карту, а не страницу
        // Пока страница грузится, WebKit заливает окно белым — в темной теме это вспышка. Свой фон не
        // рисуем: под страницей виден фон окна (темный в темной теме).
        webView.setValue(false, forKey: "drawsBackground")

        let window = GestureWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],   // обычный заголовок: кнопки окна не ложатся на поиск Google
            backing: .buffered, defer: false)
        window.title = "Maps Desktop"
        // Заголовок окна в цвет левой колонки Google: светлая rgb(244, 251, 252), в темной теме — та же
        // колонка после перекраски, rgb(30, 29, 30).
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: 30 / 255, green: 29 / 255, blue: 30 / 255, alpha: 1)
                : NSColor(srgbRed: 244 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1)
        }
        window.minSize = NSSize(width: 480, height: 360)
        window.contentView = webView
        window.mapView = webView as? MapWebView
        window.center()
        window.setFrameAutosaveName("MapWindow")
        window.isRestorable = false
        window.tabbingMode = .disallowed
        super.init(window: window)
        window.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        applyTheme()
        appearanceObservation = window.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.updateDarkMode() }
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(saveSnapshot),
            name: Notification.Name("io.github.donsamoylov.mapsdesktop.snapshot"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(runDebugScript),
            name: Notification.Name("io.github.donsamoylov.mapsdesktop.eval"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(testLocation),
            name: Notification.Name("io.github.donsamoylov.mapsdesktop.geotest"), object: nil)
        // KVO срабатывает не всегда, поэтому слушаем и системное уведомление о смене оформления.
        // Вид окна обновляется чуть позже уведомления — проверяем с задержкой.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.updateDarkMode() }
        }
    }

    private var appearanceObservation: NSKeyValueObservation?
    private var isDark: Bool?

    /// Тема из меню: «как в системе» следует за macOS, иначе окно получает свой вид.
    func applyTheme() {
        switch Theme.current {
        case .system: window?.appearance = nil
        case .light: window?.appearance = NSAppearance(named: .aqua)
        case .dark: window?.appearance = NSAppearance(named: .darkAqua)
        }
        updateDarkMode()
    }

    private func updateDarkMode() {
        let dark = window?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        guard dark != isDark else { return }
        isDark = dark
        DarkTheme.apply(dark, to: webView)
    }

    // Отладка без доступа к экрану: `defaults write local.donsamoylov.GoogleMaps GMSnapshot /путь.png`.
    // Снимок страницы и ее адрес (в .txt) сохраняются через 8 секунд после загрузки и по уведомлению
    // `io.github.donsamoylov.mapsdesktop.snapshot`.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self.saveSnapshot() }
    }

    /// Отладка: выполнить в странице скрипт из `defaults write local.donsamoylov.GoogleMaps GMEval '…'`.
    /// Работает только в режиме отладки (задан GMSnapshot).
    @objc private func runDebugScript() {
        guard UserDefaults.standard.string(forKey: "GMSnapshot") != nil,
              let js = UserDefaults.standard.string(forKey: "GMEval") else { return }
        webView.evaluateJavaScript(js)
    }

    /// Отладка геолокации: запросить координаты из страницы и записать итог в журнал.
    @objc private func testLocation() {
        LocationAccess.shared.currentLocation { location, error in
            LocationAccess.shared.log("проверка macOS: \(location.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" } ?? "нет") \(error.map { "\($0)" } ?? "")")
        }
        let js = """
            return await new Promise(done => navigator.geolocation.getCurrentPosition(
              p => done('ok ' + p.coords.latitude.toFixed(4) + ',' + p.coords.longitude.toFixed(4) + ' ±' + Math.round(p.coords.accuracy) + 'м'),
              e => done('ошибка ' + e.code + ': ' + e.message),
              { timeout: 20000 }));
            """
        webView.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { result in
            let text: String
            switch result {
            case .success(let value): text = "\(value)"
            case .failure(let error): text = "сбой скрипта: \(error)"
            }
            LocationAccess.shared.log("проверка из страницы: \(text)")
        }
    }

    @objc private func saveSnapshot() {
        guard let path = UserDefaults.standard.string(forKey: "GMSnapshot") else { return }
        let url = webView.url?.absoluteString ?? ""
        webView.evaluateJavaScript("JSON.stringify({ textures: window.__gmTextures || null, debug: window.__dbg || null })") { stats, _ in
            try? "\(url)\n\(stats ?? "")".write(toFile: path + ".txt", atomically: true, encoding: .utf8)
        }
        webView.takeSnapshot(with: nil) { image, _ in
            guard let tiff = image?.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Прозрачный фон — только на самих Картах (чтобы при загрузке не вспыхивал белый). Страницы входа
    /// и согласия на cookies рассчитаны на белый фон: без него их темный текст ложится на темное окно.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        let onMaps = webView.url.map(MapsLink.isMaps) ?? false
        webView.setValue(!onMaps, forKey: "drawsBackground")
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    // MARK: Навигация: карты и вход Google — в окне, остальное — в браузер

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, let scheme = url.scheme?.lowercased() else {
            return decisionHandler(.allow)
        }
        if ["about", "blob", "data", "javascript"].contains(scheme) { return decisionHandler(.allow) }
        if let web = MapsLink.webURL(for: url), scheme != "http" && scheme != "https" {
            load(web)
            return decisionHandler(.cancel)
        }
        if scheme != "http" && scheme != "https" {
            NSWorkspace.shared.open(url)            // tel:, mailto:, facetime: …
            return decisionHandler(.cancel)
        }
        guard action.targetFrame?.isMainFrame ?? true else { return decisionHandler(.allow) }

        let clicked = action.navigationType == .linkActivated
        if MapsLink.isMaps(url) || (!clicked && MapsLink.isGoogleService(url)) || isSignIn(url) {
            return decisionHandler(.allow)
        }
        LinkRouter.openInBrowser(url)
        decisionHandler(.cancel)
    }

    private func isSignIn(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.hasPrefix("accounts.google.") || host.hasPrefix("consent.google.") || host.hasPrefix("myaccount.google.")
    }

    /// target=_blank и window.open: карты — сюда же, остальное — в браузер.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url, url.absoluteString != "about:blank" else { return nil }
        if let web = MapsLink.webURL(for: url) { load(web) } else { LinkRouter.openInBrowser(url) }
        return nil
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.beginSheetModal(for: window!) { completionHandler($0 == .OK ? panel.urls : nil) }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: window!) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: L("Cancel"))
        alert.beginSheetModal(for: window!) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    // Геолокация: WebKit спрашивает через приватный делегат, а координаты дает, только если
    // приложению разрешила macOS — ее спрашивает LocationAccess.
    @objc(_webView:requestGeolocationPermissionForFrame:decisionHandler:)
    func requestGeolocation(_ webView: WKWebView, frame: WKFrameInfo, decisionHandler: @escaping (Bool) -> Void) {
        LocationAccess.shared.log("WebKit спрашивает разрешение (frame)")
        guard MapsLink.isGoogleService(frame.request.url ?? MapsLink.home) else { return decisionHandler(false) }
        LocationAccess.shared.request(decisionHandler)
    }

    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    func requestGeolocation(_ webView: WKWebView, origin: WKSecurityOrigin, frame: WKFrameInfo,
                            decisionHandler: @escaping (Bool) -> Void) {
        LocationAccess.shared.log("WebKit спрашивает разрешение для \(origin.host)")
        guard origin.host.contains("google.") else { return decisionHandler(false) }
        LocationAccess.shared.request(decisionHandler)
    }

    // MARK: Команды меню

    @objc func reload(_ sender: Any?) { webView.reload() }
    @objc func goBack(_ sender: Any?) { webView.goBack() }
    @objc func goForward(_ sender: Any?) { webView.goForward() }
    @objc func goHome(_ sender: Any?) { load(MapsLink.home) }
    @objc func zoomIn(_ sender: Any?) { webView.pageZoom += 0.1 }
    @objc func zoomOut(_ sender: Any?) { webView.pageZoom = max(0.5, webView.pageZoom - 0.1) }
    @objc func actualSize(_ sender: Any?) { webView.pageZoom = 1 }

    @objc func focusSearch(_ sender: Any?) {
        webView.evaluateJavaScript("""
            (document.getElementById('searchboxinput') || document.querySelector('input[name=q]'))?.select()
            """)
    }

    @objc func copyLink(_ sender: Any?) {
        guard let url = webView.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    @objc func openInBrowser(_ sender: Any?) {
        guard let url = webView.url, var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        // Метка для расширения Chrome: эту карту пользователь сам хочет открыть в браузере.
        c.queryItems = (c.queryItems ?? []) + [URLQueryItem(name: "mdkeep", value: "1")]
        LinkRouter.openInBrowser(c.url ?? url)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(goBack(_:)): return webView.canGoBack
        case #selector(goForward(_:)): return webView.canGoForward
        default: return true
        }
    }
}
