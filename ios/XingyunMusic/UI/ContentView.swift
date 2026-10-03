import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            CreateView(vm: appState.generationVM)
                .tabItem { Label("创作", systemImage: "music.note") }
                .tag(0)

            HistoryView(historyStore: appState.historyStore) { record in
                appState.generationVM.reuse(record)
                appState.selectedTab = 0
            }
            .tabItem { Label("历史", systemImage: "clock") }
            .tag(1)

            SettingsView(vm: appState.settingsVM,
                         keyStore: appState.keyStore,
                         aliasStore: appState.aliasStore,
                         settings: appState.settings)
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(2)

            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
                .tag(3)
        }
    }
}
