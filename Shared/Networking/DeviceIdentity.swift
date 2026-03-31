import CryptoKit
import Foundation
import Security

struct DeviceIdentity {

    nonisolated(unsafe) static var current: DeviceIdentity = {
        if let existing = DeviceIdentity.loadFromKeychain() {
            return existing
        }
        let key = Curve25519.Signing.PrivateKey()
        let pubKeyData = key.publicKey.rawRepresentation
        let pubKeyB64 = base64urlEncode(pubKeyData)
        let deviceId = sha256hex(pubKeyData)
        saveToKeychain(id: deviceId, privateKey: key)
        return DeviceIdentity(id: deviceId, publicKey: pubKeyB64, privateKey: key)
    }()

    let id: String
    let publicKey: String
    private let privateKey: Curve25519.Signing.PrivateKey

    private static let keychainServiceID = "ocface.device.id"
    private static let keychainServiceKey = "ocface.device.privatekey"

    func sign(payload: String) -> String {
        let data = Data(payload.utf8)
        guard let signature = try? privateKey.signature(for: data) else { return "" }
        return DeviceIdentity.base64urlEncode(signature)
    }

    func signConnect(nonce: String, token: String, signedAtMs: Int64, scopes: [String] = ["operator.admin", "operator.approvals", "operator.pairing"]) -> String {
        let scopesStr = scopes.joined(separator: ",")
        let payload = [
            "v2",
            id,
            "openclaw-control-ui",
            "webchat",
            "operator",
            scopesStr,
            String(signedAtMs),
            token,
            nonce
        ].joined(separator: "|")
        return sign(payload: payload)
    }

    // MARK: - Helpers

    private static func sha256hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    // MARK: - Keychain

    private static func loadFromKeychain() -> DeviceIdentity? {
        guard let idData = keychainLoad(service: keychainServiceID),
              let keyData = keychainLoad(service: keychainServiceKey),
              let storedId = String(data: idData, encoding: .utf8) else {
            return nil
        }

        if let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) {
            let pubKeyData = key.publicKey.rawRepresentation
            let pubKeyB64 = base64urlEncode(pubKeyData)
            let deviceId = sha256hex(pubKeyData)
            if storedId != deviceId {
                keychainSave(data: Data(deviceId.utf8), service: keychainServiceID)
            }
            return DeviceIdentity(id: deviceId, publicKey: pubKeyB64, privateKey: key)
        }

        let newKey = Curve25519.Signing.PrivateKey()
        let pubKeyData = newKey.publicKey.rawRepresentation
        let pubKeyB64 = base64urlEncode(pubKeyData)
        let deviceId = sha256hex(pubKeyData)
        saveToKeychain(id: deviceId, privateKey: newKey)
        return DeviceIdentity(id: deviceId, publicKey: pubKeyB64, privateKey: newKey)
    }

    private static func saveToKeychain(id: String, privateKey: Curve25519.Signing.PrivateKey) {
        keychainSave(data: Data(id.utf8), service: keychainServiceID)
        keychainSave(data: privateKey.rawRepresentation, service: keychainServiceKey)
    }

    private static func keychainSave(data: Data, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func keychainLoad(service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
