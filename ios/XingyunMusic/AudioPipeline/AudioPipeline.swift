import Foundation
import AVFoundation

/// 音频处理与导出管线（§8）。
/// 顺序：下载 → 校验 → （转码，由水印服务 FFmpeg 完成）→ AI 标识（平台侧）→ 双版权水印 → 写入最终目录。
final class AudioPipeline {
    private let client = APIClient.shared
    private let watermarkClient: WatermarkClient

    init(watermarkClient: WatermarkClient) {
        self.watermarkClient = watermarkClient
    }

    struct ProcessedAudio {
        var data: Data
        var fileURL: URL
        var payload: WatermarkPayload
        var verified: WatermarkDetectResult?
        var finalFormat: AudioFormat
    }

    /// 执行标准管线，返回最终音频文件 URL。
    func process(sourceURL: String,
                 config: WatermarkConfig,
                 payload: WatermarkPayload,
                 outFormat: AudioFormat) async throws -> ProcessedAudio {

        // 1. 下载原始音频（临时 URL 必须及时转存，§5 各平台）
        guard let url = URL(string: sourceURL) else { throw PipelineError.downloadFailed }
        let raw = try await client.download(url: url)

        // 2. 校验完整性（大小 + 时长，静音检测可后续扩展）
        try await validate(raw, sourceExtension: url.pathExtension)

        // 3–5. 水印（服务端同时完成转码到目标格式 + 冗余嵌入），可选立即校验
        var processed = raw
        var verified: WatermarkDetectResult? = nil
        if config.copyright, watermarkClient.isConfigured {
            processed = try await watermarkClient.embed(audioData: raw, payload: payload, targetFormat: outFormat.rawValue)
            if config.verifyAfter {
                verified = try await watermarkClient.detect(audioData: processed)
            }
        }

        // 6. 写入临时文件（最终目录由导出管理 / HistoryStore 落盘）
        let fileURL = try write(processed, ext: outFormat.rawValue)

        return ProcessedAudio(data: processed, fileURL: fileURL, payload: payload,
                              verified: verified, finalFormat: outFormat)
    }

    /// 完整性校验（§8.1 步骤 2）。
    private func validate(_ data: Data, sourceExtension: String) async throws {
        guard !data.isEmpty, data.count > 1024 else { throw PipelineError.emptyAudio }

        // 时长读取：用源格式扩展名落临时文件，交给 AVFoundation 解析
        let ext = sourceExtension.isEmpty ? "mp3" : sourceExtension
        let tmp = try write(data, ext: ext)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let asset = AVURLAsset(url: tmp)
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0.3 else { throw PipelineError.emptyAudio }
    }

    /// 写入沙盒临时目录。
    private func write(_ data: Data, ext: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xingyun-music", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PipelineError.writeFailed
        }
        return url
    }
}
