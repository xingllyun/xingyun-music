import Foundation
import Combine
import Security

/// Key 安全存储：iOS 用 Keychain（§6.3），并维护内存缓存供 UI 实时刷新。
final class KeyStore: ObservableObject {
    private let service = "com.xingyun.music.apikeys"
    private let accountPrefix = "key."

    @Published private(set) var keys: [ApiKey] = []

    init() {
        keys = loadAllFromKeychain()
    }

    func save(_ key: ApiKey) throws {
        let data = try JSONEncoder().encode(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountPrefix + key.id,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyStoreError.keychain(status: status)
        }
        upsertInMemory(key)
    }

    func load(id: String) -> ApiKey? {
        keys.first { $0.id == id }
    }

    func delete(id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountPrefix + id
        ]
        SecItemDelete(query as CFDictionary)
        keys.removeAll { $0.id == id }
    }

    /// 某平台下全部 Key（含停用，供设置页展示）。
    func all() -> [ApiKey] {
        keys
    }

    /// 某平台下全部 Key。
    func all(for providerId: String) -> [ApiKey] {
        keys.filter { $0.providerId == providerId }
    }

    private func upsertInMemory(_ key: ApiKey) {
        if let idx = keys.firstIndex(where: { $0.id == key.id }) {
            keys[idx] = key
        } else {
            keys.append(key)
        }
    }

    private func loadAllFromKeychain() -> [ApiKey] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let data = item[kSecValueData as String] as? Data else { return nil }
            return try? JSONDecoder().decode(ApiKey.self, from: data)
        }
    }
}

enum KeyStoreError: Error, LocalizedError {
    case keychain(status: OSStatus)
    var errorDescription: String? {
        if case .keychain(let s) = self { return "钥匙串错误：\(s)" }
        return nil
    }
}
