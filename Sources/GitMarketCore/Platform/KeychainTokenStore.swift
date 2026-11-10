import Foundation
import Security

/// Access tokens for private repositories or higher rate limits, one per forge host.
/// They live in the macOS Keychain and are never written to the app list file.
public struct KeychainTokenStore {
    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
    }

    private static let service = "\(AppIdentity.bundleIdentifier).token"

    public init() {}

    public func token(for host: String) throws -> String? {
        var query = baseQuery(host)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.unexpectedStatus(status)
        }
        return String(data: data, encoding: .utf8)
    }

    public func save(_ token: String, for host: String) throws {
        let data = Data(token.utf8)
        let updateStatus = SecItemUpdate(baseQuery(host) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError.unexpectedStatus(updateStatus) }

        var attributes = baseQuery(host)
        attributes[kSecValueData as String] = data
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    }

    public func delete(host: String) throws {
        let status = SecItemDelete(baseQuery(host) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(_ host: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: host,
        ]
    }
}
