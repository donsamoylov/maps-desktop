import AppKit
import WebKit

final class MapWindowController: NSWindowController, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate, NSMenuItemValidation,
                                 WKScriptMessageHandler {
    let webView: WKWebView
    private let spinner = NSProgressIndicator()

    init() {
        let config = WKWebViewConfiguration()
        // Вход в аккаунт и настройки сохраняются. У пробной сборки из папки проекта — свое хранилище: две
        // копии с одним хранилищем, запущенные вместе, перезаписывают друг другу cookies и сбрасывают вход.
        config.websiteDataStore = Bundle.main.bundlePath.contains("/build/")
            ? WKWebsiteDataStore(forIdentifier: UUID(uuidString: "6D0E6A57-2C1B-4E0E-9A4B-6E61D9A11C0B")!)
            : .default()
        config.preferences.isElementFullscreenEnabled = true
        config.userContentController.addScriptMessageHandler(LocationBridge(), contentWorld: .page,
                                                             name: LocationBridge.name)
        config.userContentController.addUserScript(LocationBridge.userScript)
        let ready = WeakMessageHandler()
        config.userContentController.add(ready, contentWorld: .page, name: "gmReady")
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
        ready.target = self
        window.delegate = self
        setUpSpinner()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        applyTheme()
        appearanceObservation = window.observe(\.effectiveAppearance) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.updateDarkMode() }
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(saveSnapshot),
            name: Notification.Name("io.github.donsamoylov.mapsdesktop.dev.snapshot"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(runDebugScript),
            name: Notification.Name("io.github.donsamoylov.mapsdesktop.dev.eval"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(testLocation),
            name: Notification.Name("io.github.donsamoylov.mapsdesktop.dev.geotest"), object: nil)
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
    // `io.github.donsamoylov.mapsdesktop.dev.snapshot`.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !(webView.url.map(MapsLink.isMaps) ?? false) { hideLoading() }   // вход в аккаунт и т.п.: карты нет
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self.saveSnapshot() }
    }

    /// Отладка: выполнить в странице скрипт из `defaults write local.donsamoylov.GoogleMaps GMEval '…'`.
    /// Работает только в режиме отладки (задан GMSnapshot).
    /// Отладка — только у сборки из папки проекта: установленное приложение на команды не отвечает.
    private var debugBuild: Bool { Bundle.main.bundlePath.contains("/build/") }

    @objc private func runDebugScript() {
        guard debugBuild, UserDefaults.standard.string(forKey: "GMSnapshot") != nil,
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
        guard debugBuild, let path = UserDefaults.standard.string(forKey: "GMSnapshot") else { return }
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
        showLoading()
        webView.load(URLRequest(url: url))
    }

    // MARK: Крутилка, пока грузится ссылка

    // Страница Карт грузится заново по каждой ссылке, а в темной теме еще и скрыта, пока карта не
    // нарисуется темной, — несколько секунд окно выглядит замершим. Пока так, по центру крутится индикатор.
    // Убираем, когда страница сообщила, что карта рисуется (gmReady из DarkTheme), а на других страницах —
    // когда они загрузились.
    private var loadingTimeout: DispatchWorkItem?

    private func setUpSpinner() {
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        webView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
        ])
    }

    private func showLoading() {
        loadingTimeout?.cancel()
        spinner.startAnimation(nil)
        let timeout = DispatchWorkItem { [weak self] in self?.hideLoading() }
        loadingTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
    }

    private func hideLoading() {
        loadingTimeout?.cancel()
        loadingTimeout = nil
        spinner.stopAnimation(nil)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "gmReady", message.frameInfo.isMainFrame { hideLoading() }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { hideLoading() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        hideLoading()
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

/// Обработчик сообщений страницы со слабой ссылкой на окно: WKUserContentController держит обработчик
/// сильно, и прямая ссылка на контроллер окна не дала бы ему освободиться.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
