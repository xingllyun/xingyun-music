import Foundation

/// Key 池：多 Key 调度与记账（§6）。
final class KeyPool {
    private let keyStore: KeyStore
    private let settings: AppSettings
    private let lock = NSLock()
    private var rrIndex: [String: Int] = [:]

    init(keyStore: KeyStore, settings: AppSettings) {
        self.keyStore = keyStore
        self.settings = settings
    }

    /// 某平台下所有可用 Key。
    func keys(for providerId: String) -> [ApiKey] {
        keyStore.all().filter { $0.providerId == providerId && $0.enabled && $0.status == .active }
    }

    /// 选择下一个 Key（§6.2）。返回 nil 表示该平台无可用 Key。
    func selectKey(providerId: String, preferred: String?) -> ApiKey? {
        lock.lock(); defer { lock.unlock() }

        let pool = keys(for: providerId)
        if let preferred = preferred, let k = pool.first(where: { $0.id == preferred }) {
            return k
        }
        guard !pool.isEmpty else { return nil }

        switch settings.schedulingStrategy {
        case .roundRobin:
            let idx = (rrIndex[providerId] ?? 0) % pool.count
            rrIndex[providerId] = idx + 1
            return pool[idx]
        case .failover:
            return pool.sorted { $0.failCount < $1.failCount }.first
        case .leastUsed:
            return pool.sorted(by: Self.leastUsedSort).first
        }
    }

    private static func leastUsedSort(_ a: ApiKey, _ b: ApiKey) -> Bool {
        let ar = a.quotaLimit.map { $0 - a.quotaUsed } ?? .greatestFiniteMagnitude
        let br = b.quotaLimit.map { $0 - b.quotaUsed } ?? .greatestFiniteMagnitude
        if ar != br { return ar > br }
        return (a.lastUsedAt ?? .distantPast) < (b.lastUsedAt ?? .distantPast)
    }

    /// 记账：累计用量 + 最近使用时间。
    func recordUsage(key: ApiKey, amount: Double) {
        var k = key
        k.quotaUsed += amount
        k.lastUsedAt = Date()
        try? keyStore.save(k)
    }

    /// 处理失败：401/403 停用，429 冷却，其余累计 failCount（§6.2）。
    func handleFailure(key: ApiKey, statusCode: Int?) {
        var k = key
        switch statusCode {
        case 401, 403:
            k.status = .disabled
            k.enabled = false
        case 429:
            k.status = .cooldown
        default:
            k.failCount += 1
        }
        try? keyStore.save(k)
    }
}
