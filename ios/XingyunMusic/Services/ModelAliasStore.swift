import Foundation
import Combine

/// 模型自定义名称映射（§7）。
struct ModelAlias: Codable, Identifiable, Equatable {
    var providerId: String
    var internalModelId: String
    var customName: String
    var enabled: Bool
    var sort: Int
    var id: String { "\(providerId):\(internalModelId)" }
}

final class ModelAliasStore: ObservableObject {
    private let defaults = UserDefaults.standard
    private let storageKey = "models.aliases"

    @Published private(set) var aliases: [ModelAlias] = []

    init() {
        if let data = defaults.data(forKey: storageKey),
           let list = try? JSONDecoder().decode([ModelAlias].self, from: data) {
            aliases = list
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(aliases) {
            defaults.set(data, forKey: storageKey)
        }
    }

    /// 是否被隐藏（enabled == false）。
    func isHidden(providerId: String, internalModelId: String) -> Bool {
        aliases.contains { $0.providerId == providerId && $0.internalModelId == internalModelId && !$0.enabled }
    }

    /// 显示名（§7）：未自定义时返回厂商默认名。
    func displayName(providerId: String, internalId: String, defaultName: String) -> String {
        if let a = aliases.first(where: { $0.providerId == providerId && $0.internalModelId == internalId && $0.enabled }),
           !a.customName.isEmpty {
            return a.customName
        }
        return defaultName
    }

    func setCustomName(_ name: String, providerId: String, internalModelId: String) {
        if let idx = aliases.firstIndex(where: { $0.providerId == providerId && $0.internalModelId == internalModelId }) {
            aliases[idx].customName = name
        } else {
            aliases.append(ModelAlias(providerId: providerId, internalModelId: internalModelId,
                                      customName: name, enabled: true, sort: aliases.count))
        }
        persist()
    }

    func setEnabled(_ enabled: Bool, providerId: String, internalModelId: String) {
        if let idx = aliases.firstIndex(where: { $0.providerId == providerId && $0.internalModelId == internalModelId }) {
            aliases[idx].enabled = enabled
        } else {
            aliases.append(ModelAlias(providerId: providerId, internalModelId: internalModelId,
                                      customName: "", enabled: enabled, sort: aliases.count))
        }
        persist()
    }
}
