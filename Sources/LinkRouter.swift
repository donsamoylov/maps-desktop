import AppKit

/// Ссылки, которые не являются картами (сайт заведения, поиск Google и т.п.), открываются
/// в браузере по умолчанию.
enum LinkRouter {
    static func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
