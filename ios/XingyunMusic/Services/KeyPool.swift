import Foundation

/// Key 池：多 Key 调度与记账（§6）。
final class KeyPool {
    private let keyStore: KeyStore
    private let settings: AppSettings
    private let lock = NSLock()
    private var rrIndex: [String: Int] = [:]

    /// 429 冷却时长（到期自动恢复）。
    private static let cooldownInterval: TimeInterval = 60

    init(keyStore: KeyStore, settings: AppSettings) {
        self.keyStore = keyStore
        self.settings = settings
    }

    /// 某平台下所有「可用」Key：enabled、非停用、冷却已过期。
    func keys(for providerId: String) -> [ApiKey] {
        let now = Date()
        return keyStore.all().filter { $0.providerId == providerId && isAvailable($0, now: now) }
    }

    private func isAvailable(_ key: ApiKey, now: Date) -> Bool {
        guard key.enabled, key.status != .disabled else { return false }
        if key.status == .cooldown { return (key.cooldownUntil ?? .distantPast) <= now }
        return true
    }

    /// 选择下一个 Key（§6.2）。返回 nil 表示该平台无可用 Key。
    func selectKey(providerId: String, preferred: String?) -> ApiKey? {
        lock.lock(); defer { lock.unlock() }

        let pool = keys(for: providerId)
        let chosen: ApiKey?
        if let preferred = preferred, let k = pool.first(where: { $0.id == preferred }) {
            chosen = k
        } else if pool.isEmpty {
            chosen = nil
        } else {
            switch settings.schedulingStrategy {
            case .roundRobin:
                let idx = (rrIndex[providerId] ?? 0) % pool.count
                rrIndex[providerId] = idx + 1
                chosen = pool[idx]
            case .failover:
                chosen = pool.sorted { $0.failCount < $1.failCount }.first
            case .leastUsed:
                chosen = pool.sorted(by: Self.leastUsedSort).first
            }
        }
        guard let chosen = chosen else { return nil }
        return reactivateIfCooldownExpired(chosen)
    }

    /// 冷却已过期的 Key 恢复为 active 并落盘。
    private func reactivateIfCooldownExpired(_ key: ApiKey) -> ApiKey {
        guard key.status == .cooldown,
              (key.cooldownUntil ?? .distantPast) <= Date() else { return key }
        var k = key
        k.status = .active
        k.cooldownUntil = nil
        try? keyStore.save(k)
        return k
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

    /// 处理失败：401/403 停用，429 进入冷却（到期自动恢复），其余累计 failCount（§6.2）。
    func handleFailure(key: ApiKey, statusCode: Int?) {
        var k = key
        switch statusCode {
        case 401, 403:
            k.status = .disabled
            k.enabled = false
        case 429:
            k.status = .cooldown
            k.cooldownUntil = Date().addingTimeInterval(Self.cooldownInterval)
        default:
            k.failCount += 1
        }
        try? keyStore.save(k)
    }
}
