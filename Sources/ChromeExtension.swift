import AppKit

/// Расширение для Chrome, которое передает ссылки на Google Карты в приложение. Ставится из Chrome Web Store.
///
/// При первом запуске (если есть Chrome) приложение предлагает установку и открывает страницу расширения
/// в магазине; отказ — больше не спрашиваем, установка остается в меню.
///
/// Раньше расширение ставилось вручную («Load unpacked») из папки в Application Support. У тех, кто так
/// его поставил (состояние "installed"), приложение и дальше обновляет эту папку при каждом запуске.
enum ChromeExtension {
    static let storeURL = URL(string: "https://chromewebstore.google.com/detail/open-in-maps-desktop/hnbhfnadfajjbilkkmpennlmlkbhjefa")!
    private static let stateKey = "chromeExtension"          // "store" | "installed" (папка) | "declined"
    private static let chromeID = "com.google.Chrome"

    private static var bundled: URL? { Bundle.main.resourceURL?.appendingPathComponent("ChromeExtension") }

    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Maps Desktop/Chrome Extension")
    }

    private static var chrome: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: chromeID) }

    /// Вызывается при запуске: предложить установку или обновить уже установленное.
    static func launch() {
        switch UserDefaults.standard.string(forKey: stateKey) {
        case "installed":
            sync()
        case "declined":
            break
        default:
            guard chrome != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { offer() }
        }
    }

    private static func offer() {
        let alert = NSAlert()
        alert.messageText = L("Open Google Maps links from Chrome in Maps Desktop?")
        alert.informativeText = L("A small Chrome extension sends map links you click in Chrome to this app. Chrome stays your default browser. It installs from the Chrome Web Store.")
        alert.addButton(withTitle: L("Install…"))
        alert.addButton(withTitle: L("Not Now"))
        if alert.runModal() == .alertFirstButtonReturn {
            install()
        } else {
            UserDefaults.standard.set("declined", forKey: stateKey)
        }
    }

    /// Страница расширения в Chrome Web Store — открываем в Chrome, расширение работает только там.
    static func install() {
        guard let chrome else {
            let alert = NSAlert()
            alert.messageText = L("Google Chrome isn’t installed")
            alert.informativeText = L("The extension works in Google Chrome. Install Chrome and choose this menu item again.")
            alert.runModal()
            return
        }
        if UserDefaults.standard.string(forKey: stateKey) != "installed" {
            UserDefaults.standard.set("store", forKey: stateKey)
        }
        NSWorkspace.shared.open([storeURL], withApplicationAt: chrome, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Копирует расширение из приложения в папку для Chrome, если файлы там отличаются.
    @discardableResult
    static func sync(force: Bool = false) -> Bool {
        guard let bundled else { return false }
        let fm = FileManager.default
        if !force, fingerprint(of: bundled) == fingerprint(of: folder) { return true }
        do {
            try fm.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
            let staging = folder.deletingLastPathComponent().appendingPathComponent(".Chrome Extension.new")
            try? fm.removeItem(at: staging)
            try fm.copyItem(at: bundled, to: staging)
            if fm.fileExists(atPath: folder.path) {
                _ = try fm.replaceItemAt(folder, withItemAt: staging)
            } else {
                try fm.moveItem(at: staging, to: folder)
            }
            return true
        } catch {
            NSLog("Chrome extension sync failed: \(error)")
            return false
        }
    }

    /// Содержимое всех файлов расширения — чтобы обновлять папку при любом изменении, а не только версии.
    private static func fingerprint(of dir: URL) -> Data? {
        guard let files = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?
            .compactMap({ $0 as? URL }).filter({ !$0.hasDirectoryPath })
            .sorted(by: { $0.path < $1.path }) else { return nil }
        var all = Data()
        for file in files {
            all.append(Data(file.path.dropFirst(dir.path.count).utf8))
            all.append((try? Data(contentsOf: file)) ?? Data())
        }
        return all
    }
}
