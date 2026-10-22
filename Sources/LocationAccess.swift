import AppKit
import CoreLocation

/// Доступ к геолокации для страницы Google Maps. WebKit отдаёт странице координаты, только если
/// само приложение получило разрешение macOS, поэтому при первом запросе страницы спрашиваем систему.
final class LocationAccess: NSObject, CLLocationManagerDelegate {
    static let shared = LocationAccess()

    private let manager = CLLocationManager()
    private var waiting: [(Bool) -> Void] = []
    private var warned = false

    private override init() {
        super.init()
        manager.delegate = self
    }

    private var granted: Bool {
        manager.authorizationStatus == .authorizedAlways          // на macOS «при использовании» отдельного статуса нет
    }

    func request(_ completion: @escaping (Bool) -> Void) {
        log("запрос страницы, статус \(manager.authorizationStatus.rawValue)")
        switch manager.authorizationStatus {
        case .notDetermined:
            waiting.append(completion)
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            completion(true)
        default:
            completion(false)
            explainDenied()
        }
    }

    private var fixWaiting: [(CLLocation?, Error?) -> Void] = []

    /// Одна свежая координата от macOS (используется вместо геолокации WebKit, которая в приложении
    /// не получает координат).
    func currentLocation(_ completion: @escaping (CLLocation?, Error?) -> Void) {
        request { granted in
            guard granted else { return completion(nil, nil) }
            if let last = self.manager.location, -last.timestamp.timeIntervalSinceNow < 30 { return completion(last, nil) }
            self.fixWaiting.append(completion)
            self.manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        log("координата от macOS: \(location.coordinate.latitude),\(location.coordinate.longitude) ±\(Int(location.horizontalAccuracy))м")
        fixWaiting.forEach { $0(location, nil) }
        fixWaiting = []
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("ошибка CoreLocation: \(error.localizedDescription)")
        fixWaiting.forEach { $0(nil, error) }
        fixWaiting = []
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        log("статус изменился: \(manager.authorizationStatus.rawValue)")
        guard manager.authorizationStatus != .notDetermined else { return }
        let answer = granted
        waiting.forEach { $0(answer) }
        waiting = []
        if !answer { explainDenied() }
    }

    /// Один раз за запуск подсказываем, где включить доступ, если macOS его не даёт.
    private func explainDenied() {
        guard !warned else { return }
        warned = true
        let alert = NSAlert()
        alert.messageText = L("No access to location")
        alert.informativeText = L("Allow Maps Desktop to use your location in System Settings ▸ Privacy & Security ▸ Location Services.")
        alert.addButton(withTitle: L("Open Settings"))
        alert.addButton(withTitle: L("Not Now"))
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Журнал решений по геолокации: ~/Library/Logs/MapsDesktop.log.
    func log(_ message: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/MapsDesktop.log")
        let line = "\(Date()) геолокация: \(message)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
