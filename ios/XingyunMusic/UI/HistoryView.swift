import SwiftUI

/// 任务历史：搜索、按平台筛选、再次生成、删除。
struct HistoryView: View {
    @ObservedObject var historyStore: HistoryStore
    var onReuse: (HistoryRecord) -> Void

    @State private var searchText = ""
    @State private var providerFilter: String = ""

    private var filtered: [HistoryRecord] {
        historyStore.records.filter { r in
            let matchProvider = providerFilter.isEmpty || r.providerId == providerFilter
            let q = searchText.trimmingCharacters(in: .whitespaces)
            let matchSearch = q.isEmpty ||
                r.modelName.localizedCaseInsensitiveContains(q) ||
                (r.lyrics ?? "").localizedCaseInsensitiveContains(q) ||
                (r.prompt ?? "").localizedCaseInsensitiveContains(q)
            return matchProvider && matchSearch
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filtered) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.modelName).font(.headline)
                            Spacer()
                            Text(r.statusText)
                                .font(.caption)
                                .foregroundColor(r.status == "success" ? .green : .red)
                        }
                        Text("\(platformDisplayName(r.providerId)) · \(r.mode.displayName) · \((r.format ?? "").uppercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let e = r.errorMessage, r.status == "failed" {
                            Text(e).font(.caption).foregroundColor(.red).lineLimit(2)
                        }
                    }
                    .contextMenu {
                        if r.status == "success" {
                            Button("再次生成") { onReuse(r) }
                        }
                        Button("删除（含文件）", role: .destructive) {
                            historyStore.delete(id: r.id, removeFile: true)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            historyStore.delete(id: r.id, removeFile: true)
                        } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索歌词 / 模型")
            .navigationTitle("历史")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("全部平台") { providerFilter = "" }
                        Button("腾讯云 TokenHub") { providerFilter = ProviderID.tencent }
                        Button("阿里云百炼") { providerFilter = ProviderID.alibaba }
                        Button("火山引擎") { providerFilter = ProviderID.volcano }
                    } label: {
                        Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("清理孤儿文件") { historyStore.clearOrphans() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
