import WebKit

/// Геолокация для страницы мимо WebKit: в приложении его источник координат не отвечает
/// (запрос страницы висит до тайм-аута), а macOS отдает координату за пару секунд.
/// Страница вызывает navigator.geolocation как обычно, скрипт пересылает запрос сюда.
final class LocationBridge: NSObject, WKScriptMessageHandlerWithReply {
    static let name = "gmGeo"

    static let userScript = WKUserScript(source: #"""
        (() => {
          const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.gmGeo;
          const geo = navigator.geolocation;
          if (!bridge || !geo || geo.__gmBridge) return;
          geo.__gmBridge = true;
          const error = (code, message) => ({ code, message, PERMISSION_DENIED: 1, POSITION_UNAVAILABLE: 2, TIMEOUT: 3 });
          const position = r => {
            const coords = { latitude: r.lat, longitude: r.lng, accuracy: r.acc, altitude: null,
                             altitudeAccuracy: null, heading: null, speed: null };
            coords.toJSON = () => ({ ...coords });
            return { coords, timestamp: r.ts, toJSON: () => ({ coords: { ...coords }, timestamp: r.ts }) };
          };
          geo.getCurrentPosition = (ok, fail) => {
            bridge.postMessage('get').then(
              r => r.error ? fail && fail(error(r.code, r.error)) : ok(position(r)),
              e => fail && fail(error(2, String(e))));
          };
          const watches = new Map();
          let next = 0;
          geo.watchPosition = (ok, fail, options) => {
            const id = ++next;
            const tick = () => geo.getCurrentPosition(ok, fail, options);
            tick();
            watches.set(id, setInterval(tick, 5000));
            return id;
          };
          geo.clearWatch = id => { clearInterval(watches.get(id)); watches.delete(id); };
        })();
        """#, injectionTime: .atDocumentStart, forMainFrameOnly: true)

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.securityOrigin.host.contains("google.") else {
            return replyHandler(["error": L("Location is available only to Google Maps pages"), "code": 1], nil)
        }
        LocationAccess.shared.currentLocation { location, error in
            guard let location else {
                let denied = error == nil      // без ошибки — значит, macOS не дала доступ
                return replyHandler(["error": error?.localizedDescription ?? L("No access to location"),
                                     "code": denied ? 1 : 2], nil)
            }
            replyHandler([
                "lat": location.coordinate.latitude,
                "lng": location.coordinate.longitude,
                "acc": location.horizontalAccuracy,
                "ts": location.timestamp.timeIntervalSince1970 * 1000,
            ], nil)
        }
    }
}
