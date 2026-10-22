import CryptoKit
import Foundation
// Ключи подписи обновлений (Ed25519).
//   swift tools/update_key.swift generate            — новый ключ: секретный и публичный, в base64
//   swift tools/update_key.swift sign <файл>         — подпись файла; секретный ключ в MAPSDESKTOP_UPDATE_KEY
//   swift tools/update_key.swift verify <файл> <подпись> <публичный>
let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "generate":
    let key = Curve25519.Signing.PrivateKey()
    print("private:", key.rawRepresentation.base64EncodedString())
    print("public: ", key.publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard let secret = ProcessInfo.processInfo.environment["MAPSDESKTOP_UPDATE_KEY"],
          let raw = Data(base64Encoded: secret.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        FileHandle.standardError.write(Data("MAPSDESKTOP_UPDATE_KEY не задан\n".utf8)); exit(1)
    }
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
    let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    print(try key.signature(for: data).base64EncodedString())
case "verify":
    let data = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: args[4])!)
    let ok = key.isValidSignature(Data(base64Encoded: args[3])!, for: data)
    print(ok ? "подпись верна" : "подпись НЕ верна"); exit(ok ? 0 : 1)
default:
    print("generate | sign <файл> | verify <файл> <подпись> <публичный ключ>")
}
