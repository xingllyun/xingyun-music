import Foundation

/// 阿里云百炼 · Fun-Music（同步，§5.2，最便宜）
final class AlibabaProvider: MusicProvider {
    var id: String { ProviderID.alibaba }
    private let settings: AppSettings
    private let client = APIClient.shared
    private let path = "/api/v1/services/audio/music/generation"

    init(settings: AppSettings) {
        self.settings = settings
    }

    private var endpoint: URL {
        let ws = settings.aliWorkspaceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = ws.isEmpty ? "dashscope.aliyuncs.com" : ws + ".cn-beijing.maas.aliyuncs.com"
        return URL(string: "https://\(host)\(path)")!
    }

    func capabilities() -> ProviderCapabilities {
        ProviderCapabilities(providerId: id,
                             supportedModes: [.customLyrics, .autoLyrics, .instrumental],
                             supportedFormats: [.mp3, .wav],
                             minDurationSec: 0, maxDurationSec: 0,
                             isAsync: false,
                             supportedGenres: [], supportedMoods: [], supportedTimbres: [])
    }

    func listModels() -> [ModelInfo] {
        [
            ModelInfo(internalId: "fun-music-v1", defaultName: "Fun-Music V1", tags: ["最便宜", "支持性别"]),
            ModelInfo(internalId: "fun-music-preview", defaultName: "Fun-Music Preview", tags: ["预览"])
        ]
    }

    func generate(_ req: MusicRequest, key: ApiKey) async throws -> MusicResult {
        var input: [String: Any] = [:]

        switch req.mode {
        case .instrumental:
            input["is_instrumental"] = true
            input["prompt"] = req.prompt ?? ""
        case .autoLyrics:
            input["prompt"] = req.prompt ?? ""
        case .customLyrics:
            input["lyrics"] = req.lyrics ?? ""
        }

        if req.mode != .instrumental, let g = req.gender {
            input["gender"] = g.rawValue
        }
        input["format"] = req.outFormat == .wav ? "wav" : "mp3"
        // 平台侧 AIGC 合规水印（§9.4，与自研双版权水印叠加）
        input["enable_aigc_watermark"] = req.watermark.aiLabel

        let body: [String: Any] = ["model": req.modelId, "input": input]
        let json = try JSONSerialization.data(withJSONObject: body)
        let headers = ["Authorization": "Bearer \(key.secret)", "Content-Type": "application/json"]

        do {
            let (data, _) = try await client.postJSON(url: endpoint, headers: headers, body: json)
            return try parse(data)
        } catch let e as HTTPError {
            throw ProviderError.http(e)
        }
    }

    private func parse(_ data: Data) throws -> MusicResult {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = obj["output"] as? [String: Any] else {
            throw ProviderError.badResponse("阿里响应结构异常")
        }
        let reason = output["finish_reason"] as? String
        guard reason == "stop" else {
            throw ProviderError.platform(code: "finish_reason", message: reason ?? "未完成", retryable: false)
        }

        let audio = output["audio"] as? [String: Any]
        let extra = output["extra_info"] as? [String: Any]
        let usageObj = obj["usage"] as? [String: Any]
        let durationSec = (usageObj?["duration"] as? NSNumber)?.doubleValue

        return MusicResult(status: .success,
                           audioUrl: audio?["url"] as? String,
                           durationMs: durationSec.map { Int($0 * 1000) },
                           sampleRate: (extra?["sample_rate"] as? String).flatMap { Int($0) },
                           channels: extra?["channels"] as? Int,
                           bitrate: nil,
                           fileSize: nil,
                           usage: durationSec.map { MusicUsage(amount: $0, unit: "seconds", providerTokens: nil) },
                           rawId: audio?["id"] as? String,
                           traceId: obj["request_id"] as? String,
                           error: nil)
    }
}
