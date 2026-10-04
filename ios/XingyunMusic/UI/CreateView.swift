import SwiftUI

/// 创作页：选模式 → 填歌词/灵感 → 选模型(别名) → 生成进度 → 试听 → 导出。
struct CreateView: View {
    @ObservedObject var vm: GenerationViewModel

    var body: some View {
        NavigationView {
            Form {
                Section("创作模式") {
                    Picker("模式", selection: $vm.mode) {
                        ForEach(CreationMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("平台与模型") {
                    Picker("平台", selection: $vm.selectedProviderId) {
                        ForEach(vm.providers(), id: \.id) { p in
                            Text(platformDisplayName(p.id)).tag(p.id)
                        }
                    }
                    .onChange(of: vm.selectedProviderId) { _ in vm.onProviderChange() }

                    Picker("模型", selection: $vm.selectedModelId) {
                        ForEach(vm.models(for: vm.selectedProviderId)) { m in
                            Text(vm.displayName(for: vm.selectedProviderId, model: m)).tag(m.internalId)
                        }
                    }
                }

                if vm.mode != .instrumental {
                    Section(vm.mode == .customLyrics ? "歌词" : "灵感（自动写词）") {
                    if vm.mode == .customLyrics {
                        TextEditor(text: $vm.lyrics)
                            .font(.custom("NotoSansCJKsc-Regular", size: 16))
                            .frame(minHeight: 140)
                                .overlay(alignment: .topLeading) {
                                    if vm.lyrics.isEmpty {
                                        Text("输入歌词，可用 [Verse][Chorus] 等结构标签分行").foregroundColor(.secondary).padding(6)
                                    }
                                }
                        } else {
                            TextEditor(text: $vm.prompt)
                                .frame(minHeight: 80)
                        }
                    }
                }

                Section("风格 / 情绪 / 场景") {
                    TextField("风格描述（如：华语流行浪漫抒情）", text: $vm.prompt)
                    if vm.mode != .instrumental {
                        Picker("性别", selection: $vm.gender) {
                            ForEach(Gender.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    TextField("曲风（可选）", text: $vm.genre)
                    TextField("情绪（可选）", text: $vm.mood)
                    TextField("音色（可选）", text: $vm.timbre)
                }

                Section("时长与导出") {
                    Stepper(value: $vm.durationSec, in: 30...240, step: 10) {
                        Text("时长：\(vm.durationSec) 秒")
                    }
                    Picker("导出格式", selection: $vm.outFormat) {
                        ForEach(AudioFormat.allCases) { Text($0.rawValue.uppercased()).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("水印与 AI 标识") {
                    Toggle("AI 生成标识", isOn: $vm.aiLabelOn)
                    Toggle("双版权隐形水印", isOn: $vm.copyrightOn)
                    Toggle("导出后校验水印", isOn: $vm.verifyAfterOn)
                }

                Section {
                    Button {
                        Task { await vm.generate() }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isGenerating {
                                ProgressView()
                                Text(vm.progressText).padding(.leading, 6)
                            } else {
                                Text("生成歌曲")
                            }
                            Spacer()
                        }
                    }
                    .disabled(vm.isGenerating)
                }

                if let err = vm.errorMessage {
                    Section("提示") {
                        Text(err).foregroundColor(.red).font(.footnote)
                    }
                }

                if let record = vm.lastRecord {
                    Section("最近完成") {
                        Text("\(record.modelName) · \(record.statusText)")
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("创作")
        }
        .navigationViewStyle(.stack)
    }
}
