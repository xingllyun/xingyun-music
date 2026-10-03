import Foundation

/// 腾讯云 TokenHub · MiniMax Music（同步，§5.1，推荐先接）
final class TencentProvider: MusicProvider {
    var id: String { ProviderID.tencent }
    private let endpoint = URL(string: "https://tokenhub.tencentmaas.com/v1/wand/minimax-music/generation")!
    private let client = APIClient.shared

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
            ModelInfo(internalId: "minimax-music-v3.0", defaultName: "MiniMax Music V3.0", tags: ["人声自然", "首选"]),
            ModelInfo(internalId: "minimax-music-v2.6", defaultName: "MiniMax Music V2.6", tags: ["稳定"])
        ]
    }

    func generate(_ req: MusicRequest, key: ApiKey) async throws -> MusicResult {
        var body: [String: Any] = ["model": req.modelId]

        switch req.mode {
        case .instrumental:
            body["is_instrumental"] = true
            body["prompt"] = req.prompt ?? ""
        case .autoLyrics:
            body["lyrics_optimizer"] = true
            if let p = req.prompt, !p.isEmpty { body["prompt"] = p }
        case .customLyrics:
            body["lyrics"] = req.lyrics ?? ""
            if let p = req.prompt, !p.isEmpty { body["prompt"] = p }
        }

        // 返回链接（12 小时有效），由音频管线及时下载转存
        body["output_format"] = "url"
        var audioSetting: [String: Any] = ["format": req.outFormat == .wav ? "wav" : "mp3"]
        if let sr = req.sampleRate { audioSetting["sample_rate"] = sr }
        if let br = req.bitrate { audioSetting["bitrate"] = br }
        body["audio_setting"] = audioSetting

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
              let base = obj["base_resp"] as? [String: Any],
              let code = base["status_code"] as? Int,
              let dataObj = obj["data"] as? [String: Any] else {
            throw ProviderError.badResponse("腾讯响应结构异常")
        }
        guard code == 0, (dataObj["status"] as? Int) == 2 else {
            let msg = base["status_msg"] as? String ?? "未知错误"
            throw ProviderError.platform(code: "\(code)", message: msg, retryable: false)
        }

        let extra = obj["extra_info"] as? [String: Any]
        let usageObj = obj["usage"] as? [String: Any]
        let tokens = usageObj?["total_tokens"] as? Int

        return MusicResult(status: .success,
                           audioUrl: dataObj["audio"] as? String,
                           durationMs: extra?["music_duration"] as? Int,
                           sampleRate: extra?["music_sample_rate"] as? Int,
                           channels: extra?["music_channel"] as? Int,
                           bitrate: extra?["bitrate"] as? Int,
                           fileSize: extra?["music_size"] as? Int,
                           usage: tokens.map { MusicUsage(amount: Double($0), unit: "tokens", providerTokens: $0) },
                           rawId: nil,
                           traceId: obj["trace_id"] as? String,
                           error: nil)
    }
}
