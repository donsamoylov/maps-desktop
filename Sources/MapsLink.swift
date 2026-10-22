import Foundation

/// Распознает ссылки на карты и переводит их в веб-адрес Google Maps.
enum MapsLink {
    static let home = URL(string: "https://www.google.com/maps")!

    /// Адрес Google Maps для входящей ссылки или nil, если это не карты.
    static func webURL(for url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased() else { return nil }
        switch scheme {
        case "mapsdesktop":
            // mapsdesktop://open?url=<адрес> — так передает ссылки расширение для Chrome.
            guard let inner = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "url" })?.value.flatMap(URL.init(string:)),
                  ["http", "https"].contains(inner.scheme?.lowercased() ?? "") else { return home }
            return webURL(for: inner)
        case "comgooglemapsurl":
            // comgooglemapsurl://www.google.com/maps/... → https://www.google.com/maps/...
            var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
            c?.scheme = "https"
            return c?.url.flatMap { isMaps($0) ? $0 : nil }
        case "comgooglemaps", "comgooglemaps-x-callback":
            return fromGoogleScheme(url)
        case "geo":
            return fromGeo(url)
        case "http", "https":
            if let inner = unwrapGoogleRedirect(url) { return webURL(for: inner) }
            if isMaps(url) { return placeByName(url) ?? url }
            if isAppleMaps(url) { return fromAppleMaps(url) }
            return nil
        default:
            return nil
        }
    }

    /// /maps/place/<название> без координат и данных Google открывает пустой карточкой —
    /// такую ссылку превращаем в поиск этого названия.
    private static func placeByName(_ url: URL) -> URL? {
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 3, parts[0] == "maps", parts[1] == "place", !parts[2].hasPrefix("@"),
              var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        c.percentEncodedPath = "/maps/search/" + (url.absoluteString.components(separatedBy: "/maps/place/").last?
            .components(separatedBy: CharacterSet(charactersIn: "/?#")).first ?? "")
        return c.url
    }

    /// Ссылка, которую Google Maps открывает у себя: google.*/maps, maps.google.*, короткие goo.gl.
    static func isMaps(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let path = url.path.lowercased()
        if host == "maps.app.goo.gl" { return true }
        if host == "goo.gl" && path.hasPrefix("/maps") { return true }
        if host.range(of: #"^maps\.google\.[a-z.]+$"#, options: .regularExpression) != nil { return true }
        if isGoogleHost(host) && (path == "/maps" || path.hasPrefix("/maps/")) { return true }
        return false
    }

    /// Хосты, без которых Google Maps не работает внутри окна: вход, согласие, капча.
    static func isGoogleService(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host == "goo.gl" || host.hasSuffix(".goo.gl") || host == "g.co" { return true }
        if host.hasSuffix(".gstatic.com") || host.hasSuffix(".googleusercontent.com") { return true }
        return isGoogleHost(host) || host.range(of: #"\.google\.[a-z.]+$"#, options: .regularExpression) != nil
    }

    private static func isGoogleHost(_ host: String) -> Bool {
        host.range(of: #"^(www\.)?google\.[a-z.]+$"#, options: .regularExpression) != nil
    }

    private static func query(_ url: URL) -> [String: String] {
        var out: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            if let v = item.value, !v.isEmpty { out[item.name] = v }
        }
        return out
    }

    private static func build(_ items: [(String, String?)]) -> URL? {
        var c = URLComponents(string: "https://www.google.com/maps")!
        let present = items.compactMap { k, v in v.map { URLQueryItem(name: k, value: $0) } }
        c.queryItems = present.isEmpty ? nil : present
        return c.url
    }

    /// google.com/url?q=… — обертка переходов из поиска и почты.
    private static func unwrapGoogleRedirect(_ url: URL) -> URL? {
        guard let host = url.host?.lowercased(), isGoogleHost(host), url.path == "/url" else { return nil }
        let q = query(url)
        return (q["q"] ?? q["url"]).flatMap(URL.init(string:))
    }

    private static let modes = ["driving": "d", "transit": "r", "walking": "w", "bicycling": "b"]

    /// comgooglemaps://?q=…&center=…&saddr=…&daddr=…&directionsmode=…&zoom=…
    private static func fromGoogleScheme(_ url: URL) -> URL? {
        let q = query(url)
        return build([
            ("q", q["q"]),
            ("ll", q["center"]),
            ("z", q["zoom"]),
            ("saddr", q["saddr"]),
            ("daddr", q["daddr"]),
            ("dirflg", q["directionsmode"].flatMap { modes[$0] }),
        ])
    }

    /// geo:55.75,37.61?q=Красная площадь
    private static func fromGeo(_ url: URL) -> URL? {
        let raw = url.absoluteString.dropFirst("geo:".count)
        let parts = raw.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let coords = parts.first ?? ""
        // geo: — непрозрачный URL, URLComponents не декодирует его запрос; разбираем сами.
        let q = parts.count > 1 ? URL(string: "x://x?" + parts[1]).map(query) ?? [:] : [:]
        let point = coords.split(separator: ";").first.map(String.init)
        let hasPoint = point.map { $0 != "0,0" && !$0.isEmpty } ?? false
        return build([("q", q["q"] ?? (hasPoint ? point : nil)), ("z", q["z"])])
    }

    private static func isAppleMaps(_ url: URL) -> Bool {
        url.host?.lowercased() == "maps.apple.com"
    }

    /// maps.apple.com/?q=…&ll=…&address=…&saddr=…&daddr=…&dirflg=…
    private static func fromAppleMaps(_ url: URL) -> URL? {
        let q = query(url)
        let dirflg: String? = switch q["dirflg"] {
        case "d": "d"
        case "w": "w"
        case "r": "r"
        default: nil
        }
        return build([
            ("q", q["q"] ?? q["address"] ?? q["ll"]),
            ("ll", q["q"] == nil ? nil : q["ll"]),
            ("z", q["z"]),
            ("saddr", q["saddr"]),
            ("daddr", q["daddr"]),
            ("dirflg", dirflg),
        ])
    }
}
