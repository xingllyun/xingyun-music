import SwiftUI

/// App 内版权页（§15）。
struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("星云音乐")
                        .font(.largeTitle).bold()

                    section("软件", "本软件由 星云云络科技 开发并享有软件著作权。\n软件版本：1.0.0")
                    section("音乐作品", "本软件生成的音乐作品（含词、曲、编曲、录音制品）相关权利归 小枯 所有。")
                    section("AI 生成说明", "本软件通过第三方音乐大模型生成音频，生成内容可能包含 AI 合成人声。作品在导出时已按规定添加 AI 生成标识及版权水印。")
                    section("开源与授权", "本软件代码公开，但仅授予查看与个人非商业使用权，禁止商用、再分发及用于训练 AI 模型，详见随附 LICENSE。")
                    section("第三方服务", "音频生成能力由 腾讯云、阿里云、火山引擎 提供，相关模型与服务的知识产权归各自权利人所有。")

                    Divider()

                    Text("版权所有 © 2026 星云云络科技；音乐版权 © 小枯。保留所有权利。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("版权与声明")
        }
        .navigationViewStyle(.stack)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundColor(.secondary)
        }
    }
}
