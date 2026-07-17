import Foundation
import Security

protocol TokenStoring: Sendable {
    func load() -> String?
    func save(_ token: String) throws
    func clear() throws
}

struct KeychainTokenVault: TokenStoring {
    private let service = "com.jordanlacroix.genengine"
    private let account = "access-token"

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) throws {
        try clearValue()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(token.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw TokenVaultError.status(status) }
    }

    func clear() throws { try clearValue() }

    private func clearValue() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound
        else { throw TokenVaultError.status(status) }
    }
}

enum TokenVaultError: LocalizedError {
    case status(OSStatus)
    var errorDescription: String? { "Keychain error (\(statusCode))." }
    private var statusCode: OSStatus {
        switch self { case let .status(status): status }
    }
}
