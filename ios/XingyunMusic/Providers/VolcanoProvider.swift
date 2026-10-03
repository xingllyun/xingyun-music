import Foundation
import CryptoKit

/// 火山引擎 · GenSong（异步 + 火山签名 V4，§5.3）
/// 鉴权为 HMAC-SHA256 签名（非 Bearer），提交后 QuerySong 轮询。
final class VolcanoProvider: MusicProvider {
    var id: String { ProviderID.volcano }
    private let client = APIClient.shared
    private let host = "open.volcengineapi.com"
    private let region = "cn-beijing"
    private let service = "imagination"
    private let version = "2024-08-12"
    private let submitAction = "GenSongForTime"
    private let queryAction = "QuerySong"

    func capabilities() -> ProviderCapabilities {
        ProviderCapabilities(providerId: id,
                             supportedModes: [.customLyrics, .autoLyrics, .instrumental],
                             supportedFormats: [.mp3, .wav],
                             minDurationSec: 30, maxDurationSec: 240,
                             isAsync: true,
                             supportedGenres: ["Pop", "Rock", "R&B", "Country", "Jazz", "Folk", "Electronic", "Classical", "Hip-Hop"],
                             supportedMoods: ["Romantic", "Sad", "Happy", "Energetic", "Calm", "Melancholic"],
                             supportedTimbres: ["Sweet_AUDIO_TIMBRE", "Deep_AUDIO_TIMBRE"])
    }

    func listModels() -> [ModelInfo] {
        [
            ModelInfo(internalId: "v4.3", defaultName: "GenSong V4.3", tags: ["参数最全", "推荐"]),
            ModelInfo(internalId: "v4.0", defaultName: "GenSong V4.0", tags: ["默认"])
        ]
    }

    func healthCheck(key: ApiKey) async throws {
        _ = try parseCredentials(key.secret)
    }

    func generate(_ req: MusicRequest, key: ApiKey) async throws -> MusicResult {
        let creds = try parseCredentials(key.secret)

        var body: [String: Any] = ["ModelVersion": req.modelId]
        switch req.mode {
        case .customLyrics, .autoLyrics:
            body["Lyrics"] = req.lyrics ?? ""
            body["Lang"] = "Chinese"
            if let g = req.gender { body["Gender"] = g.rawValue.capitalized }
        case .instrumental:
            body["Prompt"] = req.prompt ?? ""
            body["Lang"] = "Instrumental"
        }
        if let genre = req.genre { body["Genre"] = genre }
        if let mood = req.mood { body["Mood"] = mood }
        if let timbre = req.timbre { body["Timbre"] = timbre }
        if let dur = req.durationSec { body["Duration"] = dur }
        body["VodFormat"] = req.outFormat == .wav ? "wav" : "mp3"
        body["SkipCopyCheck"] = false
        // 平台侧隐私水印（§9.4，与自研双版权水印叠加）
        body["ImplicitWaterMark"] = ["Enable": true, "ContentProducer": "星云云络科技", "ProduceId": "xy001"]

        // 1. 提交任务
        let submitData = try await signedRequest(action: submitAction, ak: creds.ak, sk: creds.sk, body: body)
        let taskID = try parseSubmit(submitData)

        // 2. 轮询（每 4 秒，最长约 3 分钟）
        let deadline = Date().addingTimeInterval(200)
        while Date() < deadline {
            let queryData = try await signedRequest(action: queryAction, ak: creds.ak, sk: creds.sk, body: ["TaskID": taskID])
            if let result = try parseQuery(queryData, taskID: taskID) {
                return result
            }
            try await Task.sleep(nanoseconds: 4_000_000_000)
        }
        throw ProviderError.platform(code: "timeout", message: "火山生成超时", retryable: true)
    }

    // MARK: - 火山签名 V4（HMAC-SHA256，Region=cn-beijing，Service=imagination）

    private func signedRequest(action: String, ak: String, sk: String, body: [String: Any]) async throws -> Data {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let url = URL(string: "https://\(host)?Action=\(action)&Version=\(version)")!

        let df = DateFormatter()
        df.timeZone = TimeZone(identifier: "UTC")
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let xDate = df.string(from: Date())
        let shortDate = String(xDate.prefix(8))

        let canonicalHeaders = "content-type:application/json\nhost:\(host)\nx-date:\(xDate)\n"
        let signedHeaders = "content-type;host;x-date"
        let payloadHash = hexHash(bodyData)
        let canonicalRequest = "POST\n/\nAction=\(action)&Version=\(version)\n\(canonicalHeaders)\n\(signedHeaders)\n\(payloadHash)"

        let credentialScope = "\(shortDate)/\(region)/\(service)/request"
        let canonicalHash = hexHash(Data(canonicalRequest.utf8))
        let stringToSign = "HMAC-SHA256\n\(xDate)\n\(credentialScope)\n\(canonicalHash)"

        let kDate = hmac(key: Data(sk.utf8), message: shortDate)
        let kRegion = hmac(key: kDate, message: region)
        let kService = hmac(key: kRegion, message: service)
        let kSigning = hmac(key: kService, message: "request")
        let signature = hmac(key: kSigning, message: stringToSign).map { String(format: "%02x", $0) }.joined()

        let authorization = "HMAC-SHA256 Credential=\(ak)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(xDate, forHTTPHeaderField: "X-Date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")

        let (data, response) = try await client.post(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ProviderError.http(HTTPError(statusCode: code, body: String(data: data, encoding: .utf8) ?? ""))
        }
        return data
    }

    // MARK: - 解析

    private func parseSubmit(_ data: Data) throws -> String {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = obj["Result"] as? [String: Any],
              let taskID = result["TaskID"] as? String else {
            throw ProviderError.badResponse("火山提交响应结构异常")
        }
        return taskID
    }

    private func parseQuery(_ data: Data, taskID: String) throws -> MusicResult? {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = obj["Result"] as? [String: Any],
              let status = result["Status"] as? Int else {
            throw ProviderError.badResponse("火山查询响应结构异常")
        }
        switch status {
        case 0, 1: // 等待 / 处理中
            return nil
        case 2: // 成功
            let song = result["SongDetail"] as? [String: Any]
            let durationMs: Int?
            if let d = song?["Duration"] as? Double { durationMs = Int(d * 1000) }
            else if let d = song?["Duration"] as? Int { durationMs = d * 1000 }
            else { durationMs = nil }
            return MusicResult(status: .success,
                               audioUrl: song?["AudioUrl"] as? String,
                               durationMs: durationMs,
                               sampleRate: nil, channels: nil, bitrate: nil, fileSize: nil,
                               usage: nil,
                               rawId: taskID,
                               traceId: taskID,
                               error: nil)
        case 3: // 失败
            let fr = result["FailureReason"] as? [String: Any]
            throw ProviderError.platform(code: (fr?["Code"] as? String) ?? "3",
                                         message: (fr?["Msg"] as? String) ?? "生成失败",
                                         retryable: false)
        default:
            return nil
        }
    }

    private func parseCredentials(_ secret: String) throws -> (ak: String, sk: String) {
        let parts = secret.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw ProviderError.invalidKey("火山凭证需为「AK:SK」格式")
        }
        return (parts[0], parts[1])
    }

    // MARK: - 工具

    private func hexHash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func hmac(key: Data, message: String) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: key))
        return Data(mac)
    }
}
