import AppKit

/// Перехват ссылок: приложение становится браузером по умолчанию, карты оставляет себе,
/// всё остальное без задержки отдаёт настоящему браузеру.
enum LinkRouter {
    private static let fallbackKey = "fallbackBrowser"
    private static let probe = URL(string: "https://example.com")!

    static var isEnabled: Bool {
        guard let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
        return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    /// Браузер, куда уходят не-карты. Запоминается в момент включения перехвата.
    static var fallbackBrowser: URL {
        let ws = NSWorkspace.shared
        if let id = UserDefaults.standard.string(forKey: fallbackKey),
           let url = ws.urlForApplication(withBundleIdentifier: id) {
            return url
        }
        if let current = ws.urlForApplication(toOpen: probe),
           Bundle(url: current)?.bundleIdentifier != Bundle.main.bundleIdentifier {
            return current
        }
        return ws.urlForApplication(withBundleIdentifier: "com.apple.Safari")
            ?? URL(fileURLWithPath: "/Applications/Safari.app")
    }

    static var fallbackBrowserName: String {
        FileManager.default.displayName(atPath: fallbackBrowser.path)
            .replacingOccurrences(of: ".app", with: "")
    }

    static func openInBrowser(_ url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: fallbackBrowser, configuration: config)
    }

    static func setFallback(_ appURL: URL) {
        guard let id = Bundle(url: appURL)?.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.set(id, forKey: fallbackKey)
    }

    /// macOS сам спросит подтверждение смены браузера по умолчанию.
    static func enable(completion: @escaping (Error?) -> Void) {
        if let current = NSWorkspace.shared.urlForApplication(toOpen: probe) { setFallback(current) }
        setHandler(Bundle.main.bundleURL, completion: completion)
    }

    static func disable(completion: @escaping (Error?) -> Void) {
        setHandler(fallbackBrowser, completion: completion)
    }

    private static func setHandler(_ app: URL, completion: @escaping (Error?) -> Void) {
        NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "http") { error in
            if let error { return DispatchQueue.main.async { completion(error) } }
            NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "https") { error in
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
}
