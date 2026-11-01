import AppKit
import WebKit

enum Theme: String {
    case system, light, dark

    static var current: Theme {
        get { Theme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "theme") }
    }
}

/// Темная тема для веб-версии Google Maps: своей у сайта нет. Как она устроена — в dark-theme.js.
enum DarkTheme {
    /// Сам скрипт темы — общий с расширением для Chrome (chrome-extension/dark-theme.js).
    private static let source: String = {
        guard let url = Bundle.main.url(forResource: "dark-theme", withExtension: "js", subdirectory: "ChromeExtension"),
              let js = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("Dark theme script is missing from the app bundle")
            return "window.__gmDark = () => {};"
        }
        return js
    }()

    static func userScript(dark: Bool) -> WKUserScript {
        WKUserScript(source: source + "window.__gmDark(\(dark));",
                     injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    static func apply(_ dark: Bool, to webView: WKWebView) {
        let content = webView.configuration.userContentController
        content.removeAllUserScripts()
        content.addUserScript(LocationBridge.userScript)
        content.addUserScript(userScript(dark: dark))       // для следующих загрузок
        webView.evaluateJavaScript(source + "window.__gmDark(\(dark));")   // для открытой страницы
        webView.underPageBackgroundColor = dark ? NSColor(white: 0.1, alpha: 1) : .white
    }
}
