import Foundation
import Combine

/// Key 调度策略（§6.2）
enum KeySchedulingStrategy: String, Codable, CaseIterable, Identifiable {
    case roundRobin = "round_robin"
    case failover = "failover"
    case leastUsed = "least_used"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .roundRobin: return "轮询"
        case .failover: return "故障转移"
        case .leastUsed: return "最少使用 / 额度优先"
        }
    }
}

/// 全局设置（UserDefaults 持久化）。
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var aliWorkspaceId: String {
        didSet { defaults.set(aliWorkspaceId, forKey: Keys.aliWorkspaceId) }
    }

    @Published var watermarkServiceURL: String {
        didSet { defaults.set(watermarkServiceURL, forKey: Keys.watermarkURL) }
    }

    @Published var schedulingStrategy: KeySchedulingStrategy {
        didSet { defaults.set(schedulingStrategy.rawValue, forKey: Keys.strategy) }
    }

    init() {
        aliWorkspaceId = defaults.string(forKey: Keys.aliWorkspaceId) ?? ""
        watermarkServiceURL = defaults.string(forKey: Keys.watermarkURL) ?? ""
        let s = defaults.string(forKey: Keys.strategy) ?? ""
        schedulingStrategy = KeySchedulingStrategy(rawValue: s) ?? .roundRobin
    }

    private enum Keys {
        static let aliWorkspaceId = "settings.ali.workspaceId"
        static let watermarkURL = "settings.watermark.url"
        static let strategy = "settings.key.strategy"
    }
}
