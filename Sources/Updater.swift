import AppKit
import CryptoKit

/// Обновления из релизов GitHub. В релизе лежат MapsDesktop.zip и MapsDesktop.zip.sig — подпись архива
/// ключом Ed25519; публичная половина ключа зашита в Info.plist (NMUpdatePublicKey), поэтому
/// подменённый архив не установится. Проверка — при запуске и раз в сутки, вручную — из меню.
final class Updater: NSObject {
    static let shared = Updater()

    private let info = Bundle.main.infoDictionary ?? [:]
    private var repo: String { info["NMUpdateRepo"] as? String ?? "" }
    private var publicKey: String { info["NMUpdatePublicKey"] as? String ?? "" }
    private var current: String { info["CFBundleShortVersionString"] as? String ?? "0" }
    private var checking = false
    private var timer: Timer?

    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { self.check(interactive: false) }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            self?.check(interactive: false)
        }
    }

    @objc func checkForUpdates(_ sender: Any?) { check(interactive: true) }

    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let browser_download_url: URL }
        let tag_name: String
        let body: String?
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    func check(interactive: Bool) {
        guard !checking, !repo.isEmpty, current != "0.0.0" || interactive else { return }
        checking = true
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.checking = false
                guard let data, let release = try? JSONDecoder().decode(Release.self, from: data) else {
                    if interactive { self.tell(L("Couldn’t check for updates"), error?.localizedDescription ?? "") }
                    return
                }
                let version = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                guard Self.isNewer(version, than: self.current),
                      let zip = release.assets.first(where: { $0.name == "MapsDesktop.zip" }),
                      let sig = release.assets.first(where: { $0.name == "MapsDesktop.zip.sig" }) else {
                    if interactive {
                        self.tell(L("You’re up to date"), String(format: L("Maps Desktop %@ is the latest version."), self.current))
                    }
                    return
                }
                self.offer(version: version, notes: release.body ?? "", zip: zip.browser_download_url, sig: sig.browser_download_url)
            }
        }.resume()
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    private func offer(version: String, notes: String, zip: URL, sig: URL) {
        let alert = NSAlert()
        alert.messageText = String(format: L("Maps Desktop %@ is available"), version)
        alert.informativeText = String(format: L("You have %@."), current) + (notes.isEmpty ? "" : "\n\n" + String(notes.prefix(600)))
        alert.addButton(withTitle: L("Install and Relaunch"))
        alert.addButton(withTitle: L("Later"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        install(zip: zip, sig: sig)
    }

    private func install(zip: URL, sig: URL) {
        Task {
            do {
                let (archive, _) = try await URLSession.shared.data(from: zip)
                let (signature, _) = try await URLSession.shared.data(from: sig)
                guard let keyData = Data(base64Encoded: publicKey),
                      let sigData = Data(base64Encoded: String(decoding: signature, as: UTF8.self)
                          .trimmingCharacters(in: .whitespacesAndNewlines)),
                      try Curve25519.Signing.PublicKey(rawRepresentation: keyData).isValidSignature(sigData, for: archive)
                else { throw UpdateError(L("The update’s signature doesn’t match. It wasn’t installed.")) }

                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("maps-desktop-update-\(UUID())")
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let archiveURL = dir.appendingPathComponent("MapsDesktop.zip")
                try archive.write(to: archiveURL)
                try Self.run("/usr/bin/ditto", ["-x", "-k", archiveURL.path, dir.path])
                let newApp = dir.appendingPathComponent("Maps Desktop.app")
                guard Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                    throw UpdateError(L("The downloaded update is not Maps Desktop."))
                }
                await MainActor.run { Self.replaceAndRelaunch(with: newApp) }
            } catch {
                await MainActor.run { self.tell(L("Update failed"), error.localizedDescription) }
            }
        }
    }

    /// Старое приложение заменяется новым уже после выхода: скрипт ждёт завершения процесса.
    private static func replaceAndRelaunch(with newApp: URL) {
        let target = Bundle.main.bundleURL.path
        let script = """
            while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do /bin/sleep 0.2; done
            /bin/rm -rf "\(target)" && /bin/mv "\(newApp.path)" "\(target)"
            /usr/bin/xattr -dr com.apple.quarantine "\(target)" 2>/dev/null
            /usr/bin/open "\(target)"
            """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        try? task.run()
        NSApp.terminate(nil)
    }

    private static func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw UpdateError(L("Couldn’t unpack the update.")) }
    }

    private func tell(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }

    private struct UpdateError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
