import SwiftUI

/// 设置页：多 Key 管理、模型别名、调度策略、服务配置。
struct SettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @ObservedObject var keyStore: KeyStore
    @ObservedObject var aliasStore: ModelAliasStore
    @ObservedObject var settings: AppSettings

    @State private var showAddKey = false

    private var providers: [MusicProvider] { vm.registry.all }

    var body: some View {
        NavigationView {
            Form {
                Section("Key 调度策略") {
                    Picker("策略", selection: $settings.schedulingStrategy) {
                        ForEach(KeySchedulingStrategy.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                }

                Section("API Key 管理") {
                    ForEach(providers, id: \.id) { p in
                        let keys = keyStore.all(for: p.id)
                        DisclosureGroup {
                            if keys.isEmpty {
                                Text("暂无 Key").font(.footnote).foregroundColor(.secondary)
                            } else {
                                ForEach(keys) { k in keyRow(k) }
                            }
                            Button("添加 Key") { showAddKey = true }
                        } label: {
                            Text(platformDisplayName(p.id))
                        }
                    }
                }

                Section("模型自定义名") {
                    ForEach(providers, id: \.id) { p in
                        ForEach(vm.models(for: p.id)) { m in
                            ModelAliasRow(providerId: p.id, model: m, vm: vm)
                        }
                    }
                }

                Section("服务配置") {
                    TextField("阿里云业务空间 ID（可选）", text: $settings.aliWorkspaceId)
                    TextField("水印服务地址（可选，如 https://example.com）", text: $settings.watermarkServiceURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section("版权") {
                    Text("软件著作权：星云云络科技\n音乐作品版权：小枯")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showAddKey) {
                AddKeySheet(vm: vm)
            }
        }
        .navigationViewStyle(.stack)
    }

    private func keyRow(_ key: ApiKey) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(key.label).font(.subheadline)
                Text(key.maskedSecret).font(.caption).foregroundColor(.secondary)
                if let limit = key.quotaLimit {
                    Text("额度：\(key.quotaUsed, specifier: "%.0f") / \(limit, specifier: "%.0f")")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { key.enabled },
                set: { _ in vm.toggleKey(key) }
            ))
            .labelsHidden()
        }
        .contextMenu {
            Button("删除", role: .destructive) { vm.deleteKey(key) }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { vm.deleteKey(key) } label: { Label("删除", systemImage: "trash") }
        }
    }
}

/// 模型自定义名行（§7）。
struct ModelAliasRow: View {
    let providerId: String
    let model: ModelInfo
    @ObservedObject var vm: SettingsViewModel
    @State private var customName: String

    init(providerId: String, model: ModelInfo, vm: SettingsViewModel) {
        self.providerId = providerId
        self.model = model
        self.vm = vm
        _customName = State(initialValue: vm.aliasStore.aliases
            .first(where: { $0.providerId == providerId && $0.internalModelId == model.internalId })?.customName ?? "")
    }

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { !vm.isModelHidden(providerId: providerId, internalId: model.internalId) },
                set: { visible in vm.toggleModel(providerId: providerId, internalId: model.internalId, enabled: visible) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.defaultName).font(.footnote).foregroundColor(.secondary)
                TextField("自定义名（留空用默认）", text: $customName)
                    .onSubmit {
                        vm.renameModel(providerId: providerId, internalId: model.internalId, name: customName)
                    }
            }
        }
    }
}

/// 添加 Key 表单。
struct AddKeySheet: View {
    @ObservedObject var vm: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("平台") {
                    Picker("平台", selection: $vm.newProviderId) {
                        Text("腾讯云 TokenHub").tag(ProviderID.tencent)
                        Text("阿里云百炼").tag(ProviderID.alibaba)
                        Text("火山引擎（AK:SK）").tag(ProviderID.volcano)
                    }
                }
                Section("Key 信息") {
                    TextField("标签（可选）", text: $vm.newLabel)
                    TextField("密钥（火山填 AK:SK）", text: $vm.newSecret)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("额度上限（可选）", text: $vm.newQuotaLimit)
                        .keyboardType(.decimalPad)
                    TextField("备注（可选）", text: $vm.newNotes)
                }
                Section {
                    Button("保存") {
                        vm.addKey()
                        dismiss()
                    }
                }
            }
            .navigationTitle("添加 Key")
            .navigationBarItems(trailing: Button("取消") { dismiss() })
        }
    }
}
