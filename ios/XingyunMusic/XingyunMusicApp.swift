import SwiftUI

@main
struct XingyunMusicApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// 全局服务容器：注册 Provider、初始化 Key 池 / 别名 / 历史 / 设置 / ViewModel。
final class AppState: ObservableObject {
    static let shared = AppState()

    let registry = ProviderRegistry.shared
    let keyStore = KeyStore()
    let aliasStore = ModelAliasStore()
    let historyStore = HistoryStore()
    let settings = AppSettings()
    let keyPool: KeyPool
    let pipeline: AudioPipeline
    let generationVM: GenerationViewModel
    let settingsVM: SettingsViewModel

    @Published var selectedTab = 0

    private init() {
        registry.register(TencentProvider())
        registry.register(AlibabaProvider(settings: settings))
        registry.register(VolcanoProvider())
        registry.register(LocalProvider())
        registry.register(GenericOpenAIProvider())

        keyPool = KeyPool(keyStore: keyStore, settings: settings)
        let watermarkClient = WatermarkClient(settings: settings)
        pipeline = AudioPipeline(watermarkClient: watermarkClient)
        generationVM = GenerationViewModel(registry: registry, keyPool: keyPool,
                                           aliasStore: aliasStore, historyStore: historyStore,
                                           pipeline: pipeline)
        settingsVM = SettingsViewModel(keyStore: keyStore, aliasStore: aliasStore,
                                       settings: settings, registry: registry)
    }
}
