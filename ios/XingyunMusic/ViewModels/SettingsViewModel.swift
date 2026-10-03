import Foundation
import SwiftUI

/// 设置页 ViewModel：多 Key 增删改、模型别名、全局配置。
final class SettingsViewModel: ObservableObject {
    private let keyStore: KeyStore
    let aliasStore: ModelAliasStore
    let settings: AppSettings
    let registry: ProviderRegistry

    // 新增 Key 表单
    @Published var newProviderId = ProviderID.tencent
    @Published var newLabel = ""
    @Published var newSecret = ""
    @Published var newQuotaLimit = ""
    @Published var newNotes = ""

    @Published var keys: [ApiKey] = []

    init(keyStore: KeyStore, aliasStore: ModelAliasStore, settings: AppSettings, registry: ProviderRegistry) {
        self.keyStore = keyStore
        self.aliasStore = aliasStore
        self.settings = settings
        self.registry = registry
        self.keys = keyStore.all()
    }

    func refresh() {
        keys = keyStore.all()
    }

    func addKey() {
        let secret = newSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else { return }
        let limit = Double(newQuotaLimit.trimmingCharacters(in: .whitespacesAndNewlines))
        let key = ApiKey(providerId: newProviderId,
                         label: newLabel.isEmpty ? "未命名" : newLabel,
                         secret: secret,
                         quotaLimit: limit,
                         notes: newNotes)
        try? keyStore.save(key)
        newLabel = ""; newSecret = ""; newQuotaLimit = ""; newNotes = ""
        refresh()
    }

    func deleteKey(_ key: ApiKey) {
        keyStore.delete(id: key.id)
        refresh()
    }

    func toggleKey(_ key: ApiKey) {
        var k = key
        k.enabled.toggle()
        if k.enabled { k.status = .active }
        try? keyStore.save(k)
        refresh()
    }

    func models(for providerId: String) -> [ModelInfo] {
        registry.provider(for: providerId)?.listModels() ?? []
    }

    func renameModel(providerId: String, internalId: String, name: String) {
        aliasStore.setCustomName(name, providerId: providerId, internalModelId: internalId)
    }

    func toggleModel(providerId: String, internalId: String, enabled: Bool) {
        aliasStore.setEnabled(enabled, providerId: providerId, internalModelId: internalId)
    }

    func isModelHidden(providerId: String, internalId: String) -> Bool {
        aliasStore.isHidden(providerId: providerId, internalModelId: internalId)
    }
}
