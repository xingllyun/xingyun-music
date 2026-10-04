import Foundation
import SwiftUI

/// 生成编排 ViewModel：Key 池调度 → Provider 生成 → 音频管线 → 历史记录。
final class GenerationViewModel: ObservableObject {
    private let registry: ProviderRegistry
    private let keyPool: KeyPool
    private let aliasStore: ModelAliasStore
    private let historyStore: HistoryStore
    private let pipeline: AudioPipeline

    // 表单状态
    @Published var selectedProviderId: String = ProviderID.tencent
    @Published var selectedModelId: String = "minimax-music-v3.0"
    @Published var mode: CreationMode = .customLyrics
    @Published var lyrics: String = ""
    @Published var prompt: String = ""
    @Published var gender: Gender = .female
    @Published var genre: String = ""
    @Published var mood: String = ""
    @Published var timbre: String = ""
    @Published var durationSec: Int = 120
    @Published var outFormat: AudioFormat = .mp3
    @Published var aiLabelOn: Bool = true
    @Published var copyrightOn: Bool = true
    @Published var verifyAfterOn: Bool = true

    // 运行状态
    @Published var isGenerating = false
    @Published var progressText = ""
    @Published var errorMessage: String?
    @Published var lastRecord: HistoryRecord?

    private static let fileDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()

    init(registry: ProviderRegistry,
         keyPool: KeyPool,
         aliasStore: ModelAliasStore,
         historyStore: HistoryStore,
         pipeline: AudioPipeline) {
        self.registry = registry
        self.keyPool = keyPool
        self.aliasStore = aliasStore
        self.historyStore = historyStore
        self.pipeline = pipeline
    }

    func providers() -> [MusicProvider] { registry.all }

    func models(for providerId: String) -> [ModelInfo] {
        registry.provider(for: providerId)?.listModels() ?? []
    }

    func displayName(for providerId: String, model: ModelInfo) -> String {
        aliasStore.displayName(providerId: providerId, internalId: model.internalId, defaultName: model.defaultName)
    }

    func onProviderChange() {
        let models = self.models(for: selectedProviderId)
        selectedModelId = models.first?.internalId ?? ""
    }

    func generate() async {
        isGenerating = true
        errorMessage = nil
        lastRecord = nil
        defer { isGenerating = false }

        progressText = "正在分配 Key…"

        guard let provider = registry.provider(for: selectedProviderId) else {
            errorMessage = "未知平台"
            return
        }
        guard !keyPool.keys(for: selectedProviderId).isEmpty else {
            errorMessage = "该平台暂无可用 Key，请先在「设置」中添加"
            return
        }

        let req = MusicRequest(
            providerId: selectedProviderId,
            modelId: selectedModelId,
            mode: mode,
            lyrics: mode == .customLyrics ? lyrics : nil,
            prompt: prompt,
            gender: mode == .instrumental ? nil : gender,
            genre: genre.isEmpty ? nil : genre,
            mood: mood.isEmpty ? nil : mood,
            timbre: timbre.isEmpty ? nil : timbre,
            durationSec: durationSec,
            outFormat: outFormat,
            sampleRate: 44100,
            bitrate: 256000,
            watermark: WatermarkConfig(aiLabel: aiLabelOn, copyright: copyrightOn, verifyAfter: verifyAfterOn)
        )

        // 多 Key 容错：重试错误换下一个 Key（§6.2）
        let maxAttempts = keyPool.keys(for: selectedProviderId).count
        var result: MusicResult?
        var usedKey: ApiKey?
        var lastError: Error?

        for _ in 0..<maxAttempts {
            guard let key = keyPool.selectKey(providerId: selectedProviderId, preferred: nil) else { break }
            do {
                progressText = "正在生成（Key：\(key.label)）…"
                result = try await provider.generate(req, key: key)
                usedKey = key
                break
            } catch let e as ProviderError {
                keyPool.handleFailure(key: key, statusCode: e.failureStatusCode)
                lastError = e
                if !e.isRetryable { break }
            } catch {
                lastError = error
                break
            }
        }

        guard let result = result, let usedKey = usedKey else {
            errorMessage = (lastError as? LocalizedError)?.errorDescription ?? "生成失败"
            let modelName = aliasStore.displayName(providerId: selectedProviderId, internalId: selectedModelId, defaultName: selectedModelId)
            let failed = HistoryRecord(id: UUID().uuidString, createdAt: Date(), providerId: selectedProviderId,
                                       modelId: selectedModelId, modelName: modelName, mode: mode, lyrics: req.lyrics,
                                       prompt: req.prompt, genre: genre, mood: mood, timbre: timbre, gender: req.gender,
                                       outputPath: nil, durationMs: nil, format: outFormat.rawValue, watermarkPayload: nil,
                                       costAmount: nil, costUnit: nil, status: "failed",
                                       errorMessage: (lastError as? LocalizedError)?.errorDescription)
            historyStore.insert(failed)
            return
        }

        switch result.status {
        case .failed:
            let msg = result.error?.message ?? "生成失败"
            errorMessage = msg
            let modelName = aliasStore.displayName(providerId: selectedProviderId, internalId: selectedModelId, defaultName: selectedModelId)
            let failed = HistoryRecord(id: UUID().uuidString, createdAt: Date(), providerId: selectedProviderId,
                                       modelId: selectedModelId, modelName: modelName, mode: mode, lyrics: req.lyrics,
                                       prompt: req.prompt, genre: genre.isEmpty ? nil : genre, mood: mood.isEmpty ? nil : mood,
                                       timbre: timbre.isEmpty ? nil : timbre, gender: req.gender,
                                       outputPath: nil, durationMs: nil, format: outFormat.rawValue, watermarkPayload: nil,
                                       costAmount: nil, costUnit: nil, status: "failed", errorMessage: msg)
            historyStore.insert(failed)
        case .processing:
            errorMessage = "任务仍在处理中"
        case .success:
            do {
                if let usage = result.usage { keyPool.recordUsage(key: usedKey, amount: usage.amount) }

                guard let audioUrl = result.audioUrl else {
                    throw ProviderError.badResponse("平台未返回音频地址")
                }

                progressText = "正在导出与水印处理…"
                let workId = Self.nextWorkId()
                let payload = WatermarkPayload(aiLabel: aiLabelOn,
                                               ownerDev: WatermarkPayload.ownerDevXingyun,
                                               ownerMusic: WatermarkPayload.ownerMusicXiaoKu,
                                               workId: workId)
                let processed = try await pipeline.process(sourceURL: audioUrl, config: req.watermark, payload: payload, outFormat: outFormat)
                let finalURL = try saveFinal(processed)

                let modelName = aliasStore.displayName(providerId: selectedProviderId, internalId: selectedModelId, defaultName: selectedModelId)
                let record = HistoryRecord(
                    id: UUID().uuidString,
                    createdAt: Date(),
                    providerId: selectedProviderId,
                    modelId: selectedModelId,
                    modelName: modelName,
                    mode: mode,
                    lyrics: req.lyrics,
                    prompt: req.prompt,
                    genre: genre.isEmpty ? nil : genre,
                    mood: mood.isEmpty ? nil : mood,
                    timbre: timbre.isEmpty ? nil : timbre,
                    gender: req.gender,
                    outputPath: finalURL.path,
                    durationMs: result.durationMs,
                    format: processed.finalFormat.rawValue,
                    watermarkPayload: payload.encoded,
                    costAmount: result.usage?.amount,
                    costUnit: result.usage?.unit,
                    status: "success",
                    errorMessage: nil
                )
                historyStore.insert(record)
                lastRecord = record
                progressText = "完成"
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// 再次生成：复用历史记录参数（§10.2）。
    func reuse(_ r: HistoryRecord) {
        selectedProviderId = r.providerId
        selectedModelId = r.modelId
        mode = r.mode
        lyrics = r.lyrics ?? ""
        prompt = r.prompt ?? ""
        genre = r.genre ?? ""
        mood = r.mood ?? ""
        timbre = r.timbre ?? ""
        gender = r.gender ?? .female
        if let f = r.format { outFormat = AudioFormat(rawValue: f) ?? .mp3 }
    }

    private func saveFinal(_ processed: AudioPipeline.ProcessedAudio) throws -> URL {
        let dir = historyStore.outputDirectory()
        let name = "小枯 - " + Self.fileDateFormatter.string(from: Date()) + "-" + Self.millisSuffix() + "." + processed.finalFormat.rawValue
        let dest = dir.appendingPathComponent(name)
        do {
            try processed.data.write(to: dest, options: .atomic)
        } catch {
            throw PipelineError.writeFailed
        }
        return dest
    }

    private static func nextWorkId() -> UInt32 {
        let key = "watermark.workId.counter"
        let next = (UserDefaults.standard.integer(forKey: key) + 1) % 512
        UserDefaults.standard.set(next, forKey: key)
        return UInt32(next)
    }

    /// 毫秒后缀，避免同一秒内多次导出互相覆盖文件名。
    private static func millisSuffix() -> String {
        String(format: "%03d", Int(Date().timeIntervalSince1970 * 1000) % 1000)
    }
}
