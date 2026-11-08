import Foundation
import Security

/// Secure Keychain wrapper for UNIBODY credentials (SEC-02 hardening)
/// Replaces plaintext UserDefaults storage for sensitive passwords.
public enum KeychainHelper {
    private static let service = "app.unibody.vault"
    private static let legacyService = "de.uni-kiel.unibody.vault"

    @discardableResult
    public static func setString(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return true
        } else if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    public static func string(forKey key: String) -> String? {
        for svc in [service, legacyService] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: svc,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecSuccess, let data = result as? Data, let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return nil
    }

    public static func removeValue(forKey key: String) {
        for svc in [service, legacyService] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: svc,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    /// Safely encodes any Swift string as a JSON string literal (including quotes)
    /// for safe injection into WebKit `evaluateJavaScript` calls (SEC-04 hardening).
    public static func jsStringLiteral(_ value: String) -> String {
        if let data = try? JSONEncoder().encode(value),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }

    /// Validates that a WebView URL belongs strictly to an official CAU Kiel or DFN SSO domain (NET-02 hardening).
    public static func isTrustedCAUURL(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        if url.absoluteString == "about:blank" { return true }
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased() else {
            return false
        }
        return host == "uni-kiel.de" ||
               host.hasSuffix(".uni-kiel.de") ||
               host == "dfn.de" ||
               host.hasSuffix(".dfn.de")
    }
}
